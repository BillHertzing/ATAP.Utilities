#Requires -Version 5.1
function Get-ProjectsByActivity {
    <#
.SYNOPSIS
    Walks a directory tree and returns PowerShell and C#/.NET project roots
    sorted by most recently touched (most recently modified file in the tree).

.DESCRIPTION
    A "project root" is any directory that directly contains at least one of:
      - PowerShell:  .ps1, .psm1, .psd1, .pssc
      - C#/.NET:     .csproj, .vbproj, .fsproj, .sln
      - Both:        mixed projects are classified as "Hybrid"

    "Last touched" = the most recent LastWriteTime of any file inside the
    project root's subtree, excluding noise directories (.git, bin, obj,
    TestResults, .vs, node_modules, packages, __pycache__).

    Results are printed to the console (default) and/or returned as objects
    for piping.

.PARAMETER RootPath
    Top of the directory tree to search (default: current directory).

.PARAMETER MaxDepth
    How many levels below RootPath to look for project roots (default: 5).

.PARAMETER ExcludeDir
    Additional directory names to skip when scanning for the newest file.

.PARAMETER Type
    Filter to a project type: All | PowerShell | DotNet | Hybrid (default: All)

.PARAMETER Top
    Limit output to the N most recently touched projects.

.PARAMETER PassThru
    Return rich [PSCustomObject] results instead of formatted console output.

.EXAMPLE
    # Show top 20 projects under the current folder
    .\Get-ProjectsByActivity.ps1 -Top 20

.EXAMPLE
    # Get objects — pipe to GridView
    .\Get-ProjectsByActivity.ps1 -RootPath C:\Source -PassThru | Out-GridView

.EXAMPLE
    # Only C#/.NET projects, pass-thru for further processing
    .\Get-ProjectsByActivity.ps1 -Type DotNet -PassThru
#>
    [CmdletBinding()]
    param(
        [string]   $RootPath = (Get-Location).Path,
        [int]      $MaxDepth = 5,
        [string[]] $ExcludeDir = @(),
        [ValidateSet('All', 'PowerShell', 'DotNet', 'Hybrid')]
        [string]   $Type = 'All',
        [int]      $Top = 0,
        [switch]   $PassThru
    )

    Set-StrictMode -Version Latest

    # ─── Noise directories excluded from "newest file" scan ──────────────────────
    $NoiseDirectories = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]( '.git', '.vs', '.idea', 'bin', 'obj', 'TestResults',
            'node_modules', 'packages', '.nuget', '__pycache__',
            '.cache', 'dist', 'out', 'coverage' ) + $ExcludeDir,
        [System.StringComparer]::OrdinalIgnoreCase
    )

    # ─── Project-marker file extensions ──────────────────────────────────────────
    $PsExts = '.ps1', '.psm1', '.psd1', '.pssc'
    $DotNetExts = '.csproj', '.vbproj', '.fsproj', '.sln'

    # ─── Helper: get the most recent LastWriteTime in a project subtree ───────────
    function Get-NewestFileTime {
        param([System.IO.DirectoryInfo]$Dir)

        $newest = $Dir.LastWriteTime   # floor — at minimum the folder itself

        $stack = [System.Collections.Generic.Stack[System.IO.DirectoryInfo]]::new()
        $stack.Push($Dir)

        while ($stack.Count -gt 0) {
            $current = $stack.Pop()

            # Files in this directory
            try {
                foreach ($f in $current.EnumerateFiles()) {
                    if ($f.LastWriteTime -gt $newest) { $newest = $f.LastWriteTime }
                }
            } catch { <# access denied — skip #> }

            # Recurse into non-noise subdirs
            try {
                foreach ($sub in $current.EnumerateDirectories()) {
                    if (-not $NoiseDirectories.Contains($sub.Name)) {
                        $stack.Push($sub)
                    }
                }
            } catch { <# access denied — skip #> }
        }

        return $newest
    }

    # ─── Helper: classify a directory as a project root ──────────────────────────
    function Get-ProjectType {
        param([System.IO.DirectoryInfo]$Dir)

        $hasPs = $false
        $hasDotNet = $false

        try {
            foreach ($f in $Dir.EnumerateFiles()) {
                $ext = $f.Extension.ToLowerInvariant()
                if ($PsExts -contains $ext) { $hasPs = $true }
                if ($DotNetExts -contains $ext) { $hasDotNet = $true }
                if ($hasPs -and $hasDotNet) { break }
            }
        } catch { <# access denied #> }

        if ($hasPs -and $hasDotNet) { return 'Hybrid' }
        if ($hasDotNet) { return 'DotNet' }
        if ($hasPs) { return 'PowerShell' }
        return $null
    }

    # ─── Walk the tree up to MaxDepth, collecting project roots ──────────────────
    Write-Verbose "Scanning: $RootPath  (MaxDepth=$MaxDepth)"

    $projectRoots = [System.Collections.Generic.List[PSCustomObject]]::new()

    # BFS with depth tracking: item = [DirectoryInfo, currentDepth]
    $queue = [System.Collections.Generic.Queue[object]]::new()
    $queue.Enqueue( [PSCustomObject]@{ Dir = [System.IO.DirectoryInfo]$RootPath; Depth = 0 } )

    while ($queue.Count -gt 0) {
        $item = $queue.Dequeue()
        $dir = $item.Dir
        $depth = $item.Depth

        # Skip noise dirs anywhere in the tree
        if ($NoiseDirectories.Contains($dir.Name)) { continue }

        $ptype = Get-ProjectType -Dir $dir

        if ($ptype) {
            # Found a project root — record it; do NOT descend further
            # (avoids treating nested projects as duplicates of the parent)
            $newestTime = Get-NewestFileTime -Dir $dir
            $projectRoots.Add([PSCustomObject]@{
                    Type        = $ptype
                    Name        = $dir.Name
                    Path        = $dir.FullName
                    LastTouched = $newestTime
                    Age         = (Get-Date) - $newestTime
                })
        } elseif ($depth -lt $MaxDepth) {
            # Not a project root — go deeper
            try {
                foreach ($sub in $dir.EnumerateDirectories()) {
                    if (-not $NoiseDirectories.Contains($sub.Name)) {
                        $queue.Enqueue([PSCustomObject]@{ Dir = $sub; Depth = $depth + 1 })
                    }
                }
            } catch { <# access denied #> }
        }
    }

    # ─── Sort by most recently touched ───────────────────────────────────────────
    $sorted = $projectRoots |
        Where-Object { $Type -eq 'All' -or $_.Type -eq $Type } |
        Sort-Object LastTouched -Descending

    if ($Top -gt 0) { $sorted = $sorted | Select-Object -First $Top }

    # ─── Output ───────────────────────────────────────────────────────────────────
    if ($PassThru) {
        return $sorted
    }

    # Pretty console table
    $typeColors = @{
        'PowerShell' = 'Cyan'
        'DotNet'     = 'Green'
        'Hybrid'     = 'Magenta'
    }

    $rank = 1
    Write-Host ''
    Write-Host ('{0,-4} {1,-10} {2,-22} {3}' -f '#', 'Type', 'Last Touched', 'Path') -ForegroundColor White
    Write-Host ('{0,-4} {1,-10} {2,-22} {3}' -f '────', '──────────', '──────────────────────', '────────────────────────────────────────') -ForegroundColor DarkGray

    foreach ($p in $sorted) {
        $age = switch ($true) {
            ($p.Age.TotalMinutes -lt 60) { "$([int]$p.Age.TotalMinutes)m ago" }
            ($p.Age.TotalHours -lt 24) { "$([int]$p.Age.TotalHours)h ago" }
            ($p.Age.TotalDays -lt 7) { "$([int]$p.Age.TotalDays)d ago" }
            default { $p.LastTouched.ToString('yyyy-MM-dd') }
        }

        $col = $typeColors[$p.Type]
        Write-Host ('{0,-4}' -f $rank) -NoNewline -ForegroundColor DarkGray
        Write-Host ('{0,-10}' -f $p.Type) -NoNewline -ForegroundColor $col
        Write-Host ('{0,-22}' -f $age) -NoNewline -ForegroundColor Yellow
        Write-Host $p.Path -ForegroundColor White
        $rank++
    }

    Write-Host ''
    Write-Host "  $($sorted.Count) project(s) found under: $RootPath" -ForegroundColor DarkGray
    Write-Host ''
}

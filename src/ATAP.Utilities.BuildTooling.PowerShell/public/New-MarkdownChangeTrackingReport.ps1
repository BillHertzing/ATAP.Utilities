# Load contract: dot-source this file to define New-MarkdownChangeTrackingReport.
# No top-level code executes on load - all side effects occur only when the
# function is called.
function New-MarkdownChangeTrackingReport {
  <#
  .SYNOPSIS
    Generates a self-contained HTML report describing the change-tracking
    header status of every Markdown file under a folder tree.
  .DESCRIPTION
    Recursively scans -Path for `*.md` files, reads the first ten lines of each
    file, and classifies whether a change-tracking header is present. A file is
    considered tracked when one of the following appears in its preview:

      * an HTML comment opening `<!-- change-tracking:`
      * a `change-tracking:` line
      * a `last-updated:` line

    Files are grouped by their containing folder (relative to -Path) and rendered
    into a single static HTML document with a sticky navigation pane, per-file
    cards showing the preview text, and a summary banner of scanned / tracked /
    untracked counts. All file content is HTML-encoded before being written into
    the report, so arbitrary Markdown is safe to embed.

    The report is written to -Output. Any missing parent directories are created.
    Per repository convention (SC-0033), callers should target a path under the
    repository `_generated/` folder so the report is treated as a generated
    artifact rather than source.
  .PARAMETER Path
    Root folder to scan recursively for Markdown files. Must exist.
  .PARAMETER Output
    Destination path for the generated HTML report. Missing parent directories
    are created. Aliased as `-o`.
  .PARAMETER SolutionDocumentationOnly
    When set, restricts the scan to Markdown files whose path contains a
    `SolutionDocumentation` folder segment.
  .OUTPUTS
    System.IO.FileInfo - the generated HTML report file.
  .EXAMPLE
    New-MarkdownChangeTrackingReport -Path 'C:\repo' -Output 'C:\repo\_generated\md-change-tracking.html'

    Scans every Markdown file under the repository and writes the report into
    the `_generated` folder.
  .EXAMPLE
    New-MarkdownChangeTrackingReport -Path 'C:\repo' -o 'C:\repo\_generated\sd-tracking.html' -SolutionDocumentationOnly

    Reports only on Markdown files that live under a `SolutionDocumentation`
    folder.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [Alias('o')]
    [string]$Output,

    [switch]$SolutionDocumentationOnly
  )

  begin {
    Set-StrictMode -Version Latest
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Local HTML-encode helper. Defined inside the function so nothing executes
    # at module load; null/empty input collapses to an empty string.
    function ConvertTo-HtmlText {
      param([string]$Text)
      if ([string]::IsNullOrEmpty($Text)) { return '' }
      return [System.Net.WebUtility]::HtmlEncode($Text)
    }
  }

  process {
    if (-not (Test-Path -LiteralPath $Path)) {
      throw "New-MarkdownChangeTrackingReport: -Path '$Path' does not exist."
    }

    $root = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Scanning Markdown files under '$root' (SolutionDocumentationOnly=$SolutionDocumentationOnly)."

    $files = @(
      Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.md' |
        Where-Object {
          if ($SolutionDocumentationOnly) {
            $_.FullName -match '(?i)[\\/]+SolutionDocumentation([\\/]|$)'
          } else {
            $true
          }
        } |
        Sort-Object FullName
    )

    $items = @(
      foreach ($file in $files) {
        $relativePath = [System.IO.Path]::GetRelativePath($root, $file.FullName)
        $folderRelative = [System.IO.Path]::GetRelativePath($root, $file.DirectoryName)
        if ([string]::IsNullOrWhiteSpace($folderRelative) -or $folderRelative -eq '.') {
          $folderRelative = '(root)'
        }

        $firstLines = Get-Content -LiteralPath $file.FullName -TotalCount 10 -ErrorAction Stop
        $previewText = if ($firstLines) { $firstLines -join "`r`n" } else { '' }

        $hasTrackedHeader =
          $previewText -match '(?im)^<!--\s*change-tracking:' -or
          $previewText -match '(?im)^change-tracking\s*:' -or
          $previewText -match '(?im)^last-updated\s*:'

        [pscustomobject]@{
          Folder           = $folderRelative
          FileName         = $file.Name
          RelativePath     = $relativePath
          FullName         = $file.FullName
          Preview          = $previewText
          HasTrackedHeader = $hasTrackedHeader
          AnchorId         = ('f_' + ([Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes($relativePath)).ToLowerInvariant()))
        }
      }
    )

    $grouped = $items | Group-Object Folder | Sort-Object Name

    $navBuilder = [System.Text.StringBuilder]::new()
    $contentBuilder = [System.Text.StringBuilder]::new()

    [void]$navBuilder.AppendLine('<ul class="nav-root">')

    foreach ($group in $grouped) {
      $folderEncoded = ConvertTo-HtmlText $group.Name
      [void]$navBuilder.AppendLine("<li class=""nav-folder""><div class=""nav-folder-title"">$folderEncoded</div>")
      [void]$navBuilder.AppendLine('<ul class="nav-files">')

      [void]$contentBuilder.AppendLine('<section class="folder-section">')
      [void]$contentBuilder.AppendLine("<h2>$folderEncoded</h2>")

      foreach ($item in ($group.Group | Sort-Object RelativePath)) {
        $fileNameEncoded = ConvertTo-HtmlText $item.FileName
        $relativeEncoded = ConvertTo-HtmlText $item.RelativePath
        $previewEncoded = ConvertTo-HtmlText $item.Preview
        $statusClass = if ($item.HasTrackedHeader) { 'status-yes' } else { 'status-no' }
        $statusText = if ($item.HasTrackedHeader) { 'Header detected' } else { 'No header detected' }

        [void]$navBuilder.AppendLine(
          "<li><a href=""#$($item.AnchorId)"" class=""nav-link $statusClass"">$fileNameEncoded</a></li>"
        )

        [void]$contentBuilder.AppendLine(@"
<article class="file-card" id="$($item.AnchorId)">
  <div class="file-header">
    <h3>$fileNameEncoded</h3>
    <span class="status-badge $statusClass">$statusText</span>
  </div>
  <div class="file-meta">$relativeEncoded</div>
  <pre>$previewEncoded</pre>
</article>
"@)
      }

      [void]$contentBuilder.AppendLine('</section>')
      [void]$navBuilder.AppendLine('</ul></li>')
    }

    [void]$navBuilder.AppendLine('</ul>')

    $generated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'
    $reportTitle = 'Markdown Change-Tracking Report'
    $trackedCount = @($items | Where-Object HasTrackedHeader).Count
    $untrackedCount = @($items | Where-Object { -not $_.HasTrackedHeader }).Count
    $rootEncoded = ConvertTo-HtmlText $root

    $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$reportTitle</title>
<style>
:root {
  color-scheme: light dark;
  --bg: #0b0f14;
  --panel: #121821;
  --panel2: #18212c;
  --text: #e6edf3;
  --muted: #9fb0c3;
  --border: #2d3a4a;
  --accent: #58a6ff;
  --ok: #3fb950;
  --warn: #f85149;
}
html, body { margin: 0; padding: 0; font-family: Segoe UI, Arial, sans-serif; background: var(--bg); color: var(--text); }
.layout { display: grid; grid-template-columns: 320px 1fr; min-height: 100vh; }
nav { position: sticky; top: 0; height: 100vh; overflow: auto; border-right: 1px solid var(--border); background: var(--panel); padding: 16px; box-sizing: border-box; }
main { padding: 24px; }
h1, h2, h3 { margin-top: 0; }
.report-meta { color: var(--muted); margin-bottom: 16px; }
.nav-root, .nav-files { list-style: none; padding-left: 0; margin: 0; }
.nav-folder { margin-bottom: 16px; }
.nav-folder-title { font-weight: 700; color: var(--text); margin-bottom: 6px; word-break: break-word; }
.nav-link { display: block; padding: 6px 8px; margin: 2px 0; color: var(--text); text-decoration: none; border-radius: 6px; word-break: break-word; }
.nav-link:hover { background: var(--panel2); }
.folder-section { margin-bottom: 32px; }
.file-card { border: 1px solid var(--border); background: var(--panel); border-radius: 10px; padding: 16px; margin-bottom: 16px; }
.file-header { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
.file-meta { color: var(--muted); font-size: 0.95rem; margin-bottom: 12px; }
pre { white-space: pre-wrap; word-break: break-word; overflow-wrap: anywhere; background: #0a0e13; border: 1px solid var(--border); border-radius: 8px; padding: 12px; }
.status-badge { display: inline-block; padding: 4px 8px; border-radius: 999px; font-size: 0.85rem; font-weight: 700; }
.status-yes { color: #d2f4d7; background: rgba(63,185,80,0.2); }
.status-no { color: #ffd7d5; background: rgba(248,81,73,0.2); }
.summary { display: flex; gap: 16px; flex-wrap: wrap; margin-bottom: 24px; }
.summary .tile { background: var(--panel); border: 1px solid var(--border); border-radius: 10px; padding: 12px 14px; }
@media (max-width: 900px) {
  .layout { grid-template-columns: 1fr; }
  nav { position: relative; height: auto; border-right: 0; border-bottom: 1px solid var(--border); }
}
</style>
</head>
<body>
<div class="layout">
  <nav>
    <h1>$reportTitle</h1>
    <div class="report-meta">Generated: $generated</div>
    $($navBuilder.ToString())
  </nav>
  <main>
    <div class="summary">
      <div class="tile">Files scanned: $($items.Count)</div>
      <div class="tile">Header detected: $trackedCount</div>
      <div class="tile">Missing header: $untrackedCount</div>
      <div class="tile">Root: $rootEncoded</div>
    </div>
    $($contentBuilder.ToString())
  </main>
</div>
</body>
</html>
"@

    $parent = Split-Path -Parent $Output
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
      if ($PSCmdlet.ShouldProcess($parent, 'Create output directory')) {
        $null = New-Item -ItemType Directory -Path $parent -Force
      }
    }

    if ($PSCmdlet.ShouldProcess($Output, 'Write Markdown change-tracking report')) {
      Set-Content -LiteralPath $Output -Value $html -Encoding UTF8
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Wrote Markdown change-tracking report for $($items.Count) file(s) ($trackedCount tracked, $untrackedCount untracked) to '$Output'."
      Get-Item -LiteralPath $Output
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting function $fn"
  }
}

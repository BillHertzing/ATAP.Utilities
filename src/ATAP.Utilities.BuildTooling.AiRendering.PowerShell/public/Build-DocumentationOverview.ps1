function Build-DocumentationOverview {
  <#
  .SYNOPSIS
  Catalogs every documentation file across one or more ATAP repositories and reports
  statistics, unresolved relative links, and missing expected documents.

  .DESCRIPTION
  Build-DocumentationOverview is the repeatable form of the cross-repository
  documentation survey. For each repository root it enumerates the Git-tracked
  documentation files (Markdown, HTML, PlantUML, Draw.io, EBNF), extracts each
  file's title and first sentence, classifies it by top-level area and as
  curated documentation or point-in-time evidence, and checks every relative
  Markdown link in curated documents.

  Rendered AI-adapter surfaces (.claude, .agents, .gemini, .codex and the rendered
  .github sub-folders) are excluded by default because they are generated copies
  of the SharedVSCode .ai canonical sources.

  The command writes four files under the output root (SC-0033 _generated folder):

    DocumentationCatalog.csv              one row per document
    UnresolvedLinks.csv                   one row per unresolved relative link
    DocumentationOverview.Summary.json    machine-readable totals
    DocumentationOverview.Statistics.md   human-readable statistics section

  The narrative README (glossary, reading paths, findings) stays human-authored;
  this command regenerates the facts that go stale.

  The command reads only. It never modifies a repository file outside the output
  root and never contacts a remote.

  .PARAMETER RepositoryRoot
  One or more repository or worktree roots. Each must contain a .git entry (a
  directory for a clone, a file for a linked worktree). Pass sprint worktree roots
  during a sprint and stable roots otherwise; the command never guesses a root.

  .PARAMETER OutputRoot
  Directory that receives the generated files. Defaults to
  <first RepositoryRoot>\_generated\DocumentationOverview.

  .PARAMETER IncludeExtension
  File extensions treated as documentation.

  .PARAMETER ExcludePathPattern
  Regular expression matched against the repository-relative path (forward
  slashes). Matching files are not cataloged.

  .PARAMETER EvidencePathPattern
  Regular expression matched against the repository-relative path. Matching
  files are cataloged with IsEvidence = true and are skipped by the link check.

  .PARAMETER ExpectedDocument
  Documents that indexes or instructions promise, in the form
  'RepositoryName:relative/path.md'. Each missing one is reported. The repository
  name is the root's leaf folder name with any '-wt-...' sprint suffix removed.

  .PARAMETER SkipLinkCheck
  Skip relative-link resolution.

  .PARAMETER TopBrokenFileCount
  Number of files listed in the 'most unresolved links' table.

  .OUTPUTS
  PSCustomObject summarizing the run and naming the files written.

  .EXAMPLE
  $roots = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities', 'C:\Dropbox\whertzing\GitHub\Ace',
           'C:\Dropbox\whertzing\GitHub\SharedVSCode', 'C:\Dropbox\whertzing\GitHub\_Planning',
           'C:\Dropbox\whertzing\GitHub\ATAP.IAC'
  Build-DocumentationOverview -RepositoryRoot $roots `
    -ExpectedDocument 'ATAP.Utilities:SolutionDocumentation/Rules Compendium.md'

  .EXAMPLE
  Build-DocumentationOverview -RepositoryRoot $roots -WhatIf

  .NOTES
  Requires git on PATH. Supports -WhatIf and -Confirm through ShouldProcess.
  Link resolution is case-insensitive on every platform, matching Windows.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]] $RepositoryRoot,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputRoot,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]] $IncludeExtension = @('.md', '.html', '.htm', '.puml', '.plantuml', '.uml', '.drawio', '.ebnf'),

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $ExcludePathPattern = '^(\.claude|\.agents|\.gemini|\.codex|\.github/(skills|instructions|agents|prompts)|node_modules)/',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $EvidencePathPattern = '^(InformationForTheFuture/Sprint\d{4}/|SprintHistory/|SprintRetrospective/|Archived/|DocumentationReview/)',

    [Parameter(Mandatory = $false)]
    [ValidateScript({ $_ -match '^[^:]+:.+$' })]
    [string[]] $ExpectedDocument = @(),

    [Parameter(Mandatory = $false)]
    [switch] $SkipLinkCheck,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 500)]
    [int] $TopBrokenFileCount = 25
  )

  begin {
    $fn = 'Build-DocumentationOverview'
    $mn = 'ATAP.Utilities.BuildTooling.AiRendering.PowerShell'

    if (-not (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue)) {
      throw "$fn requires the PSFramework command Write-PSFMessage."
    }

    function Write-OverviewMessage {
      param(
        [Parameter(Mandatory = $true)] [string] $Message,
        [Parameter(Mandatory = $false)] [ValidateSet('Debug', 'Verbose', 'Important', 'Error')] [string] $Level = 'Verbose'
      )
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level $Level -Message $Message
    }

    function Get-RepositoryDisplayName {
      param([Parameter(Mandatory = $true)] [string] $Root)
      # Sprint worktrees are named <StableRoot>-wt-<n>-sprint-<nnnn>-work-items.
      return ((Split-Path -Path $Root -Leaf) -replace '-wt-.*$', '')
    }

    function Invoke-GitText {
      param(
        [Parameter(Mandatory = $true)] [string] $Root,
        [Parameter(Mandatory = $true)] [string[]] $Arguments
      )
      # Native diagnostics are not document names or revision data.
      $output = & git -C $Root -c core.quotepath=off @Arguments 2>$null
      if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed in '$Root' (exit $LASTEXITCODE); stderr was discarded."
      }
      return @($output | ForEach-Object { [string]$_ })
    }

    function Get-DocumentHeader {
      param(
        [Parameter(Mandatory = $true)] [string] $FullPath,
        [Parameter(Mandatory = $true)] [string] $Extension
      )
      $title = ''
      $first = ''
      $text = ''
      try {
        $raw = [System.IO.File]::ReadAllText($FullPath)
        $text = if ($raw.Length -gt 20000) { $raw.Substring(0, 20000) } else { $raw }
      }
      catch {
        Write-OverviewMessage -Level Debug -Message "Unreadable '$FullPath': $($_.Exception.Message)"
        return [pscustomobject]@{ Title = ''; FirstSentence = '' }
      }

      switch ($Extension) {
        '.md' {
          $body = [regex]::Replace($text, '(?s)\A---\r?\n.*?\r?\n---\r?\n', '')
          $m = [regex]::Match($body, '(?m)^#\s+(.+?)\s*$')
          if ($m.Success) { $title = $m.Groups[1].Value }
          foreach ($para in [regex]::Split($body, '\r?\n\s*\r?\n')) {
            $s = $para.Trim()
            if (-not $s) { continue }
            if ($s -match '^(#|\||```|<!--|---|>|- \[|!\[|<)') { continue }
            $first = ([regex]::Replace($s, '\s+', ' '))
            break
          }
          if (-not $first) {
            $d = [regex]::Match($text, '(?m)^description:\s*(.+)$')
            if ($d.Success) { $first = $d.Groups[1].Value }
          }
        }
        { $_ -in '.html', '.htm' } {
          $m = [regex]::Match($text, '(?is)<title>(.*?)</title>')
          if ($m.Success) { $title = $m.Groups[1].Value.Trim() }
        }
        { $_ -in '.puml', '.plantuml', '.uml' } {
          $m = [regex]::Match($text, '(?im)^\s*title\s+(.+?)\s*$')
          if ($m.Success) { $title = $m.Groups[1].Value }
        }
        '.drawio' {
          $names = [regex]::Matches($text, '<diagram[^>]*\bname="([^"]*)"') | Select-Object -First 6 | ForEach-Object { $_.Groups[1].Value }
          $title = ($names -join ';')
        }
      }
      if ($first.Length -gt 220) { $first = $first.Substring(0, 220) }
      return [pscustomobject]@{ Title = $title; FirstSentence = $first }
    }

    function Test-PathCaseInsensitive {
      param([Parameter(Mandatory = $true)] [string] $Path)
      if (Test-Path -LiteralPath $Path) { return $true }
      if ($IsWindows) { return $false }
      # Non-Windows: walk components case-insensitively so results match Windows.
      $full = [System.IO.Path]::GetFullPath($Path)
      $current = [System.IO.Path]::GetPathRoot($full)
      foreach ($part in $full.Substring($current.Length).Split([char[]]@('/', '\'), [System.StringSplitOptions]::RemoveEmptyEntries)) {
        if (-not (Test-Path -LiteralPath $current -PathType Container)) { return $false }
        $match = Get-ChildItem -LiteralPath $current -Force -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -ieq $part } | Select-Object -First 1
        if (-not $match) { return $false }
        $current = $match.FullName
      }
      return $true
    }

    function Get-UnresolvedLink {
      param(
        [Parameter(Mandatory = $true)] [string] $FullPath,
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [string] $Text
      )
      $withoutCode = [regex]::Replace($Text, '(?s)```.*?```', '')
      $directory = Split-Path -Path $FullPath -Parent
      $total = 0
      $bad = [System.Collections.Generic.List[string]]::new()
      foreach ($m in [regex]::Matches($withoutCode, '\[[^\]]*\]\((?:<([^<>\r\n]*)>|([^\s()<>]+))(?:\s+"[^"]*")?\)')) {
        $target = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
        if ($target -match '^(?:[A-Za-z][A-Za-z0-9+.-]*:|#)') { continue }
        $target = [System.Uri]::UnescapeDataString(($target -split '#', 2)[0])
        if (-not $target) { continue }
        $total++
        if (-not (Test-PathCaseInsensitive -Path (Join-Path $directory $target))) { $bad.Add($target) }
      }
      return [pscustomobject]@{ Total = $total; Unresolved = $bad.ToArray() }
    }

    function ConvertTo-MarkdownCell {
      param([AllowNull()] [AllowEmptyString()] [object] $Value)
      return ([string]$Value) -replace '\|', '\|' -replace '\r?\n', ' '
    }

    $includeSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($ext in $IncludeExtension) { [void]$includeSet.Add(($ext.StartsWith('.') ? $ext : ".$ext")) }

    if (-not (Get-Command -Name git -ErrorAction SilentlyContinue)) {
      throw "$fn requires git on PATH."
    }
  }

  end {
    try {
      # ---- Validate roots (fail closed; never guess) --------------------------------
      $roots = foreach ($root in $RepositoryRoot) {
        $resolved = (Resolve-Path -LiteralPath $root -ErrorAction Stop).ProviderPath
        if (-not (Test-Path -LiteralPath (Join-Path $resolved '.git'))) {
          throw "RepositoryRoot '$resolved' has no .git entry; pass a repository or worktree root."
        }
        [pscustomobject]@{ Root = $resolved; Name = Get-RepositoryDisplayName -Root $resolved }
      }
      $duplicateNames = $roots | Group-Object Name | Where-Object Count -gt 1
      if ($duplicateNames) {
        throw "Two roots map to the same repository name: $($duplicateNames.Name -join ', '). Pass one root per repository."
      }

      if (-not $OutputRoot) {
        $OutputRoot = Join-Path (Join-Path $roots[0].Root '_generated') 'DocumentationOverview'
      }

      # Only generated areas are valid destinations. Reject reparse points in the
      # complete existing path, including report files, so lexical containment
      # cannot be redirected to a maintained location.
      $OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
      $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
      foreach ($repo in $roots) {
        $repoPath = [System.IO.Path]::GetFullPath($repo.Root).TrimEnd([char[]]@('/', '\'))
        $separator = [System.IO.Path]::DirectorySeparatorChar
        $repoPrefix = $repoPath + $separator
        $generatedPrefix = (Join-Path $repoPath '_generated').TrimEnd([char[]]@('/', '\')) + $separator
        $destination = $OutputRoot.TrimEnd([char[]]@('/', '\'))
        if (($destination.Equals($repoPath, $comparison) -or $destination.StartsWith($repoPrefix, $comparison)) -and
            -not $destination.StartsWith($generatedPrefix, $comparison)) {
          throw "OutputRoot '$OutputRoot' must be a descendant of a repository _generated directory or ARTIFACTS_PATH, and cannot target maintained repository content."
        }
      }
      $allowed = @($roots | ForEach-Object { [System.IO.Path]::GetFullPath((Join-Path $_.Root '_generated')) })
      if (-not [string]::IsNullOrWhiteSpace($env:ARTIFACTS_PATH)) {
        $allowed += [System.IO.Path]::GetFullPath($env:ARTIFACTS_PATH)
      }
      $inside = $false
      foreach ($base in $allowed) {
        $prefix = $base.TrimEnd([char[]]@('/', '\')) + [System.IO.Path]::DirectorySeparatorChar
        if ($OutputRoot.StartsWith($prefix, $comparison)) { $inside = $true; break }
      }
      if (-not $inside) { throw "OutputRoot '$OutputRoot' must be a descendant of a repository _generated directory or ARTIFACTS_PATH." }
      $destinations = @($OutputRoot) + @('DocumentationCatalog.csv', 'UnresolvedLinks.csv', 'DocumentationOverview.Summary.json', 'DocumentationOverview.Statistics.md' | ForEach-Object { Join-Path $OutputRoot $_ })
      foreach ($destination in $destinations) {
        $current = $destination
        while ($current) {
          if ((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "OutputRoot contains a reparse point: '$current'."
          }
          $parent = [IO.Path]::GetDirectoryName($current)
          if ($parent -eq $current) { break }
          $current = $parent
        }
      }

      # ---- Catalog --------------------------------------------------------------------
      $catalog = [System.Collections.Generic.List[object]]::new()
      $unresolved = [System.Collections.Generic.List[object]]::new()
      $linkTotals = @{}
      $sources = [System.Collections.Generic.List[object]]::new()

      foreach ($repo in $roots) {
        Write-OverviewMessage -Level Verbose -Message "Cataloging $($repo.Name) at $($repo.Root)"
        $branch = @(Invoke-GitText -Root $repo.Root -Arguments @('rev-parse', '--abbrev-ref', 'HEAD'))[0]
        $commit = @(Invoke-GitText -Root $repo.Root -Arguments @('rev-parse', '--short', 'HEAD'))[0]
        $sources.Add([pscustomobject]@{ Repository = $repo.Name; Root = $repo.Root; Branch = $branch; Commit = $commit })

        $tracked = @(Invoke-GitText -Root $repo.Root -Arguments @('ls-files'))
        $linkTotals[$repo.Name] = [pscustomobject]@{ Links = 0; Unresolved = 0 }

        foreach ($relative in $tracked) {
          if (-not $relative) { continue }
          $extension = [System.IO.Path]::GetExtension($relative)
          if (-not $includeSet.Contains($extension)) { continue }
          if ($relative -match $ExcludePathPattern) { continue }

          $fullPath = Join-Path $repo.Root $relative
          if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { continue }   # deleted in working tree / sparse
          $header = Get-DocumentHeader -FullPath $fullPath -Extension $extension.ToLowerInvariant()
          $isEvidence = $relative -match $EvidencePathPattern
          $area = if ($relative.Contains('/')) { $relative.Split('/')[0] } else { '(root)' }

          $catalog.Add([pscustomobject]@{
              Repository    = $repo.Name
              Area          = $area
              IsEvidence    = [bool]$isEvidence
              Path          = $relative
              Type          = $extension.TrimStart('.').ToLowerInvariant()
              SizeBytes     = (Get-Item -LiteralPath $fullPath).Length
              Title         = $header.Title
              FirstSentence = $header.FirstSentence
            })

          if (-not $SkipLinkCheck -and -not $isEvidence -and $extension -ieq '.md') {
            $linkResult = Get-UnresolvedLink -FullPath $fullPath -Text ([System.IO.File]::ReadAllText($fullPath))
            $linkTotals[$repo.Name].Links += $linkResult.Total
            $linkTotals[$repo.Name].Unresolved += $linkResult.Unresolved.Count
            foreach ($target in $linkResult.Unresolved) {
              $unresolved.Add([pscustomobject]@{ Repository = $repo.Name; SourcePath = $relative; Link = $target })
            }
          }
        }
      }

      $catalog = @($catalog | Sort-Object Repository, Path)
      $unresolved = @($unresolved | Sort-Object Repository, SourcePath, Link)

      # ---- Expected documents ---------------------------------------------------------
      $missingExpected = foreach ($expected in $ExpectedDocument) {
        $repoName, $relativePath = $expected -split ':', 2
        $repo = $roots | Where-Object Name -ieq $repoName | Select-Object -First 1
        if (-not $repo) {
          Write-OverviewMessage -Level Important -Message "ExpectedDocument '$expected' names a repository that was not scanned."
          [pscustomobject]@{ ExpectedDocument = $expected; Reason = 'RepositoryNotScanned' }
          continue
        }
        if (-not (Test-PathCaseInsensitive -Path (Join-Path $repo.Root $relativePath))) {
          [pscustomobject]@{ ExpectedDocument = $expected; Reason = 'Missing' }
        }
      }
      $missingExpected = @($missingExpected)

      # ---- Statistics -----------------------------------------------------------------
      $perRepo = foreach ($repo in $roots) {
        $docs = @($catalog | Where-Object Repository -eq $repo.Name)
        $byType = [ordered]@{}
        foreach ($g in ($docs | Group-Object Type | Sort-Object Name)) { $byType[$g.Name] = $g.Count }
        [pscustomobject]@{
          Repository = $repo.Name
          Total      = $docs.Count
          Curated    = @($docs | Where-Object { -not $_.IsEvidence }).Count
          Evidence   = @($docs | Where-Object IsEvidence).Count
          ByType     = $byType
          Links      = $linkTotals[$repo.Name].Links
          Unresolved = $linkTotals[$repo.Name].Unresolved
        }
      }
      $untitledDiagrams = @($catalog | Where-Object { $_.Type -in 'puml', 'plantuml', 'uml' -and -not $_.Title -and -not $_.IsEvidence })
      $topBroken = @($unresolved | Group-Object Repository, SourcePath | Sort-Object Count -Descending | Select-Object -First $TopBrokenFileCount)

      $generatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
      $md = [System.Text.StringBuilder]::new()
      [void]$md.AppendLine('# Documentation overview — generated statistics')
      [void]$md.AppendLine()
      [void]$md.AppendLine("Generated $generatedAt by ``$fn``. Do not edit by hand; re-run the command.")
      [void]$md.AppendLine()
      [void]$md.AppendLine('| Repository | Branch | Commit |')
      [void]$md.AppendLine('| --- | --- | --- |')
      foreach ($s in $sources) { [void]$md.AppendLine("| $($s.Repository) | ``$($s.Branch)`` | ``$($s.Commit)`` |") }
      [void]$md.AppendLine()
      [void]$md.AppendLine('## Documents by repository')
      [void]$md.AppendLine()
      $types = @($catalog.Type | Sort-Object -Unique)
      [void]$md.AppendLine('| Repository | Total | Curated | Evidence | ' + ($types -join ' | ') + ' |')
      [void]$md.AppendLine('| --- | ---: | ---: | ---: | ' + (($types | ForEach-Object { '---:' }) -join ' | ') + ' |')
      foreach ($r in $perRepo) {
        $cells = $types | ForEach-Object { if ($r.ByType.Contains($_)) { $r.ByType[$_] } else { 0 } }
        [void]$md.AppendLine("| $($r.Repository) | $($r.Total) | $($r.Curated) | $($r.Evidence) | " + ($cells -join ' | ') + ' |')
      }
      [void]$md.AppendLine("| **Total** | **$($catalog.Count)** | **$(@($catalog | Where-Object { -not $_.IsEvidence }).Count)** | **$(@($catalog | Where-Object IsEvidence).Count)** | " + (($types | ForEach-Object { $t = $_; "**$(@($catalog | Where-Object Type -eq $t).Count)**" }) -join ' | ') + ' |')
      [void]$md.AppendLine()
      [void]$md.AppendLine('## Documents by top-level area')
      [void]$md.AppendLine()
      [void]$md.AppendLine('| Repository | Area | Documents | Evidence |')
      [void]$md.AppendLine('| --- | --- | ---: | ---: |')
      foreach ($g in ($catalog | Group-Object Repository, Area | Sort-Object { $_.Group[0].Repository }, { - $_.Count })) {
        [void]$md.AppendLine("| $($g.Group[0].Repository) | $(ConvertTo-MarkdownCell $g.Group[0].Area) | $($g.Count) | $(@($g.Group | Where-Object IsEvidence).Count) |")
      }
      if (-not $SkipLinkCheck) {
        [void]$md.AppendLine()
        [void]$md.AppendLine('## Relative links in curated Markdown')
        [void]$md.AppendLine()
        [void]$md.AppendLine('| Repository | Relative links | Unresolved |')
        [void]$md.AppendLine('| --- | ---: | ---: |')
        foreach ($r in $perRepo) { [void]$md.AppendLine("| $($r.Repository) | $($r.Links) | $($r.Unresolved) |") }
        if ($topBroken.Count) {
          [void]$md.AppendLine()
          [void]$md.AppendLine("### Files with the most unresolved links (top $TopBrokenFileCount)")
          [void]$md.AppendLine()
          [void]$md.AppendLine('| Unresolved | Repository | File | Example |')
          [void]$md.AppendLine('| ---: | --- | --- | --- |')
          foreach ($g in $topBroken) {
            [void]$md.AppendLine("| $($g.Count) | $($g.Group[0].Repository) | $(ConvertTo-MarkdownCell $g.Group[0].SourcePath) | ``$(ConvertTo-MarkdownCell $g.Group[0].Link)`` |")
          }
        }
      }
      [void]$md.AppendLine()
      [void]$md.AppendLine('## Expected documents')
      [void]$md.AppendLine()
      if (-not $ExpectedDocument.Count) { [void]$md.AppendLine('No expected documents were supplied.') }
      elseif (-not $missingExpected.Count) { [void]$md.AppendLine("All $($ExpectedDocument.Count) expected documents are present.") }
      else { foreach ($m in $missingExpected) { [void]$md.AppendLine("- **$($m.Reason):** ``$(ConvertTo-MarkdownCell $m.ExpectedDocument)``") } }
      [void]$md.AppendLine()
      [void]$md.AppendLine("## PlantUML diagrams without a title ($($untitledDiagrams.Count))")
      [void]$md.AppendLine()
      foreach ($d in $untitledDiagrams) { [void]$md.AppendLine("- $($d.Repository): ``$(ConvertTo-MarkdownCell $d.Path)``") }

      $summary = [ordered]@{
        GeneratedAt             = $generatedAt
        Command                 = $fn
        Sources                 = @($sources)
        DocumentCount           = $catalog.Count
        CuratedCount            = @($catalog | Where-Object { -not $_.IsEvidence }).Count
        EvidenceCount           = @($catalog | Where-Object IsEvidence).Count
        LinkCheckSkipped        = [bool]$SkipLinkCheck
        UnresolvedLinkCount     = $unresolved.Count
        MissingExpectedDocument = @($missingExpected)
        UntitledDiagramCount    = $untitledDiagrams.Count
        PerRepository           = @($perRepo | Select-Object Repository, Total, Curated, Evidence, ByType, Links, Unresolved)
      }

      # ---- Write ----------------------------------------------------------------------
      $files = [ordered]@{
        Catalog    = Join-Path $OutputRoot 'DocumentationCatalog.csv'
        Unresolved = Join-Path $OutputRoot 'UnresolvedLinks.csv'
        Summary    = Join-Path $OutputRoot 'DocumentationOverview.Summary.json'
        Statistics = Join-Path $OutputRoot 'DocumentationOverview.Statistics.md'
      }
      $written = $false
      if ($PSCmdlet.ShouldProcess($OutputRoot, "Write documentation overview for $($roots.Count) repositories ($($catalog.Count) documents)")) {
        New-Item -ItemType Directory -Path $OutputRoot -Force -ErrorAction Stop | Out-Null
        if ($catalog.Count) {
          $catalog | Export-Csv -LiteralPath $files.Catalog -NoTypeInformation -Encoding utf8NoBOM -ErrorAction Stop
        }
        else {
          Set-Content -LiteralPath $files.Catalog -Value '"Repository","Area","IsEvidence","Path","Type","SizeBytes","Title","FirstSentence"' -Encoding utf8NoBOM -ErrorAction Stop
        }
        if ($unresolved.Count) {
          $unresolved | Export-Csv -LiteralPath $files.Unresolved -NoTypeInformation -Encoding utf8NoBOM -ErrorAction Stop
        }
        else {
          Set-Content -LiteralPath $files.Unresolved -Value '"Repository","SourcePath","Link"' -Encoding utf8NoBOM -ErrorAction Stop
        }
        $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $files.Summary -Encoding utf8NoBOM -ErrorAction Stop
        Set-Content -LiteralPath $files.Statistics -Value $md.ToString() -Encoding utf8NoBOM -NoNewline -ErrorAction Stop
        $written = $true
        Write-OverviewMessage -Level Important -Message "Wrote documentation overview for $($catalog.Count) documents to $OutputRoot"
      }

      [pscustomobject]@{
        PSTypeName              = 'ATAP.DocumentationOverview.Result'
        OutputRoot              = $OutputRoot
        Written                 = $written
        RepositoryCount         = $roots.Count
        DocumentCount           = $catalog.Count
        CuratedCount            = $summary.CuratedCount
        EvidenceCount           = $summary.EvidenceCount
        UnresolvedLinkCount     = $unresolved.Count
        MissingExpectedDocument = @($missingExpected | ForEach-Object ExpectedDocument)
        Files                   = [pscustomobject]$files
      }
    }
    catch {
      Write-OverviewMessage -Level Error -Message "$fn failed: $($_.Exception.Message)"
      throw
    }
  }
}

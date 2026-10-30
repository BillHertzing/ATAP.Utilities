BeforeAll {
  # PSFramework may not be loaded in a bare test shell; stub the logger so the
  # function under test can be dot-sourced and called without the dependency.
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  . "$PSScriptRoot\..\..\public\New-MarkdownChangeTrackingReport.ps1"

  # Helper: build a small Markdown tree under a fresh temp root and return it.
  function script:New-TestMarkdownTree {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) "mdtrack_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    # Root-level file WITH an HTML-comment change-tracking header.
    Set-Content -LiteralPath (Join-Path $root 'tracked-comment.md') -Encoding UTF8 -Value @'
<!-- change-tracking: 2026-06-19 -->
# Tracked Comment
Body text.
'@

    # Root-level file WITH a last-updated header.
    Set-Content -LiteralPath (Join-Path $root 'tracked-lastupdated.md') -Encoding UTF8 -Value @'
last-updated: 2026-06-19
# Tracked Last Updated
'@

    # Subfolder file WITHOUT any tracking header.
    $docs = Join-Path $root 'docs'
    New-Item -ItemType Directory -Path $docs -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $docs 'untracked.md') -Encoding UTF8 -Value @'
# Untracked Doc
No header here.
'@

    # SolutionDocumentation file (used by the -SolutionDocumentationOnly test).
    $sd = Join-Path $root 'SolutionDocumentation'
    New-Item -ItemType Directory -Path $sd -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $sd 'compendium.md') -Encoding UTF8 -Value @'
change-tracking: yes
# Compendium
'@

    return $root
  }
}

Describe 'New-MarkdownChangeTrackingReport LF output' -Tag 'Unit' {
  BeforeAll {
    $script:lfBase = 'D:\ATAPArtifacts\Sprint0017\Task17.9.b\CoreReportLF329\Fixtures'
    $null = [IO.Directory]::CreateDirectory($script:lfBase)
  }
  It 'writes UTF8 LF output and preserves the <Kind> input bytes' -ForEach @(
    @{ Kind = 'LF'; Eol = "`n" },
    @{ Kind = 'CRLF'; Eol = "`r`n" },
    @{ Kind = 'CR'; Eol = "`r" }
  ) {
    $case = Join-Path $script:lfBase ([guid]::NewGuid().ToString('N'))
    $source = Join-Path $case 'source'
    $null = [IO.Directory]::CreateDirectory($source)
    $inputPath = Join-Path $source 'unicode.md'
    $outputPath = Join-Path $case 'report.html'
    $inputBytes = [Text.UTF8Encoding]::new($false).GetBytes("last-updated: yes${Eol}# café <example>${Eol}")
    [IO.File]::WriteAllBytes($inputPath, $inputBytes)

    New-MarkdownChangeTrackingReport -Path $source -Output $outputPath | Out-Null

    $actual = [IO.File]::ReadAllBytes($outputPath)
    [array]::IndexOf($actual, [byte]13) | Should -Be -1
    $actual[-1] | Should -Be 10
    ($actual.Length -ge 3 -and $actual[0] -eq 0xEF -and $actual[1] -eq 0xBB -and $actual[2] -eq 0xBF) | Should -BeFalse
    $html = [Text.UTF8Encoding]::new($false, $true).GetString($actual)
    $html | Should -Match 'Header detected'
    [Net.WebUtility]::HtmlDecode($html) | Should -Match 'café <example>'
    $html | Should -Match '&lt;example&gt;'
    [Convert]::ToHexString([IO.File]::ReadAllBytes($inputPath)) | Should -BeExactly ([Convert]::ToHexString($inputBytes))
  }
  It 'does not create an output or parent under WhatIf' {
    $case = Join-Path $script:lfBase ([guid]::NewGuid().ToString('N'))
    $source = Join-Path $case 'source'
    $null = [IO.Directory]::CreateDirectory($source)
    $inputPath = Join-Path $source 'source.md'
    [IO.File]::WriteAllText($inputPath, "# café`n", [Text.UTF8Encoding]::new($false))
    $before = (Get-FileHash $inputPath).Hash
    $parent = Join-Path $case 'not-created'
    New-MarkdownChangeTrackingReport -Path $source -Output (Join-Path $parent 'report.html') -WhatIf | Out-Null
    Test-Path -LiteralPath $parent | Should -BeFalse
    (Get-FileHash $inputPath).Hash | Should -BeExactly $before
  }
}

Describe 'New-MarkdownChangeTrackingReport [public]' -Tag 'Unit' {
  BeforeEach {
    $script:root = script:New-TestMarkdownTree
    $script:outDir = Join-Path ([System.IO.Path]::GetTempPath()) "mdtrack_out_$([guid]::NewGuid().ToString('N'))"
    $script:output = Join-Path $script:outDir 'report.html'
  }

  AfterEach {
    Remove-Item -LiteralPath $script:root -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $script:outDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'writes the report and returns a FileInfo for the output path' {
    $result = New-MarkdownChangeTrackingReport -Path $script:root -Output $script:output

    $result | Should -BeOfType ([System.IO.FileInfo])
    $result.FullName | Should -Be ([System.IO.Path]::GetFullPath($script:output))
    Test-Path -LiteralPath $script:output | Should -BeTrue
  }

  It 'creates missing parent directories for the output file' {
    Test-Path -LiteralPath $script:outDir | Should -BeFalse
    New-MarkdownChangeTrackingReport -Path $script:root -Output $script:output | Out-Null
    Test-Path -LiteralPath $script:output | Should -BeTrue
  }

  It 'accepts the -o alias for -Output' {
    New-MarkdownChangeTrackingReport -Path $script:root -o $script:output | Out-Null
    Test-Path -LiteralPath $script:output | Should -BeTrue
  }

  It 'reports the correct scanned / tracked / untracked counts' {
    New-MarkdownChangeTrackingReport -Path $script:root -Output $script:output | Out-Null
    $html = Get-Content -LiteralPath $script:output -Raw

    # 4 files total: 3 tracked (comment, last-updated, change-tracking), 1 untracked.
    $html | Should -Match 'Files scanned: 4'
    $html | Should -Match 'Header detected: 3'
    $html | Should -Match 'Missing header: 1'
  }

  It 'classifies tracked files as status-yes and untracked files as status-no' {
    New-MarkdownChangeTrackingReport -Path $script:root -Output $script:output | Out-Null
    $html = Get-Content -LiteralPath $script:output -Raw

    $html | Should -Match 'tracked-comment\.md'
    $html | Should -Match 'untracked\.md'
    # The untracked file must carry the no-header badge text somewhere in the doc.
    $html | Should -Match 'No header detected'
    $html | Should -Match 'Header detected'
  }

  It 'HTML-encodes file preview content so embedded markup is inert' {
    Set-Content -LiteralPath (Join-Path $script:root 'danger.md') -Encoding UTF8 -Value @'
# <marker-xyz>
last-updated: 2026-06-19
'@
    New-MarkdownChangeTrackingReport -Path $script:root -Output $script:output | Out-Null
    $html = Get-Content -LiteralPath $script:output -Raw

    $html | Should -Match '&lt;marker-xyz&gt;'
    $html | Should -Not -Match '<marker-xyz>'
  }

  It 'restricts the scan to SolutionDocumentation when -SolutionDocumentationOnly is set' {
    New-MarkdownChangeTrackingReport -Path $script:root -Output $script:output -SolutionDocumentationOnly | Out-Null
    $html = Get-Content -LiteralPath $script:output -Raw

    $html | Should -Match 'Files scanned: 1'
    $html | Should -Match 'compendium\.md'
    $html | Should -Not -Match 'untracked\.md'
  }

  It 'throws when -Path does not exist' {
    $missing = Join-Path ([System.IO.Path]::GetTempPath()) "mdtrack_missing_$([guid]::NewGuid().ToString('N'))"
    { New-MarkdownChangeTrackingReport -Path $missing -Output $script:output } |
      Should -Throw '*does not exist*'
  }

  It 'does not write the report under -WhatIf' {
    New-MarkdownChangeTrackingReport -Path $script:root -Output $script:output -WhatIf | Out-Null
    Test-Path -LiteralPath $script:output | Should -BeFalse
  }
}

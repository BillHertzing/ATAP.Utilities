# AI assisted using Powershell.instructions.md as guidelines
# Pester 6.2+ tests for Build-DocumentationOverview

BeforeAll {
  $functionName = 'Build-DocumentationOverview'
  $functionPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../public/$functionName.ps1")).ProviderPath
  . $functionPath
  if ((Get-Command -Name $functionName -CommandType Function).ScriptBlock.File -ne $functionPath) {
    throw "Test did not bind the intended source: $functionPath"
  }

  # Creates a committed Git repository from a hashtable of relative path -> content.
  # Paths listed in -Untracked are written but not added.
  function New-TestRepository {
    param(
      [Parameter(Mandatory = $true)] [string] $Path,
      [Parameter(Mandatory = $true)] [hashtable] $Files,
      [Parameter(Mandatory = $false)] [hashtable] $Untracked = @{}
    )
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    & git -C $Path init -q -b main 2>&1 | Out-Null
    foreach ($key in $Files.Keys) {
      $full = Join-Path $Path $key
      New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
      [IO.File]::WriteAllText($full, [string]$Files[$key], [Text.UTF8Encoding]::new($false))
    }
    & git -C $Path add -A 2>&1 | Out-Null
    & git -C $Path -c user.email=test@example.invalid -c user.name=test commit -q -m init 2>&1 | Out-Null
    foreach ($key in $Untracked.Keys) {
      $full = Join-Path $Path $key
      New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
      Set-Content -LiteralPath $full -Value $Untracked[$key] -Encoding utf8NoBOM
    }
    return (Resolve-Path -LiteralPath $Path).ProviderPath
  }
}

Describe 'Build-DocumentationOverview' {

  BeforeAll {
    $script:repoA = New-TestRepository -Path (Join-Path $TestDrive 'RepoA') -Files @{
      'README.md'                           = "# Repo A`n`nRepo A is the first test repository.`n`nSee [guide](Docs/Guide.md), [CASE](docs/guide.md), [web](https://example.com), [anchor](#top), [abs](file:///C:/x.md), [missing](Docs/Nope.md)."
      'Docs/Guide.md'                       = "---`ndescription: front matter`n---`n# Guide`n`n| table | row |`n`nThe guide body.`n`n``````text`n[not a link](Docs/AlsoMissing.md)`n```````n"
      'Docs/Diagram.puml'                   = "@startuml`ntitle Repo A Diagram`nA -> B`n@enduml"
      'Docs/Untitled.puml'                  = "@startuml`nA -> B`n@enduml"
      'Docs/Layout.drawio'                  = '<mxfile><diagram name="Page One" id="1"></diagram><diagram name="Page Two" id="2"></diagram></mxfile>'
      'Docs/notes.txt'                      = 'not documentation'
      'Docs/Empty.md'                       = ''
      '.claude/agents/agent.md'             = '# Rendered agent copy'
      '.github/instructions/x.md'           = '# Rendered instruction copy'
      '.github/workflows/README.md'         = '# Real workflow notes'
      'SprintHistory/Sprint0001/Notes.md'   = "# Evidence`n`n[dead](Gone.md)"
    } -Untracked @{ 'Docs/Draft.md' = '# Untracked draft' }

    $script:repoB = New-TestRepository -Path (Join-Path $TestDrive 'RepoB-wt-7-sprint-0001-work-items') -Files @{
      'ReadMe.md' = "# Repo B`n`nBack to [A](../RepoA/README.md)."
    }

    $script:result = Build-DocumentationOverview -RepositoryRoot $script:repoA, $script:repoB `
      -ExpectedDocument 'RepoA:Docs/Guide.md', 'RepoA:Docs/RulesCompendium.md', 'Unknown:x.md' -Confirm:$false
    $script:catalog = Import-Csv -LiteralPath $script:result.Files.Catalog
    $script:links = @(Import-Csv -LiteralPath $script:result.Files.Unresolved)
  }

  Context 'Cataloging' {
    It 'binds the exact submitted source file' {
      (Get-Command Build-DocumentationOverview -CommandType Function).ScriptBlock.File | Should -Be $functionPath
    }

    It 'catalogs a zero-byte Markdown file without adding links' {
      $empty = $script:catalog | Where-Object Path -eq 'Docs/Empty.md'
      $empty.SizeBytes | Should -Be '0'
      @($script:links | Where-Object SourcePath -eq 'Docs/Empty.md').Count | Should -Be 0
      $script:result.Written | Should -BeTrue
    }
    It 'catalogs only tracked documentation files with included extensions' {
      $paths = $script:catalog | Where-Object Repository -eq 'RepoA' | ForEach-Object Path
      $paths | Should -Contain 'README.md'
      $paths | Should -Contain 'Docs/Layout.drawio'
      $paths | Should -Not -Contain 'Docs/notes.txt'
      $paths | Should -Not -Contain 'Docs/Draft.md'
    }

    It 'excludes rendered AI-adapter surfaces but keeps other .github content' {
      $paths = $script:catalog | ForEach-Object Path
      $paths | Should -Not -Contain '.claude/agents/agent.md'
      $paths | Should -Not -Contain '.github/instructions/x.md'
      $paths | Should -Contain '.github/workflows/README.md'
    }

    It 'strips the sprint worktree suffix from the repository name' {
      $script:catalog.Repository | Should -Contain 'RepoB'
      $script:catalog.Repository | Should -Not -Contain 'RepoB-wt-7-sprint-0001-work-items'
    }

    It 'extracts Markdown titles and skips front matter and tables for the first sentence' {
      $guide = $script:catalog | Where-Object Path -eq 'Docs/Guide.md'
      $guide.Title | Should -Be 'Guide'
      $guide.FirstSentence | Should -Be 'The guide body.'
    }

    It 'extracts PlantUML titles and Draw.io page names' {
      ($script:catalog | Where-Object Path -eq 'Docs/Diagram.puml').Title | Should -Be 'Repo A Diagram'
      ($script:catalog | Where-Object Path -eq 'Docs/Layout.drawio').Title | Should -Be 'Page One;Page Two'
    }

    It 'flags evidence paths' {
      ($script:catalog | Where-Object Path -eq 'SprintHistory/Sprint0001/Notes.md').IsEvidence | Should -Be 'True'
      ($script:catalog | Where-Object Path -eq 'README.md' | Where-Object Repository -eq 'RepoA').IsEvidence | Should -Be 'False'
    }
  }

  Context 'Link checking' {
    It 'reports only genuinely unresolved relative links' {
      $script:links.Count | Should -Be 1
      $script:links[0].SourcePath | Should -Be 'README.md'
      $script:links[0].Link | Should -Be 'Docs/Nope.md'
    }

    It 'ignores links in fenced code and in evidence files' {
      $script:links.Link | Should -Not -Contain 'Docs/AlsoMissing.md'
      $script:links.Link | Should -Not -Contain 'Gone.md'
    }

    It 'resolves cross-repository relative links' {
      $script:links | Where-Object Repository -eq 'RepoB' | Should -BeNullOrEmpty
    }

    It 'returns the unresolved count on the result object' {
      $script:result.UnresolvedLinkCount | Should -Be 1
    }
  }

  Context 'Expected documents and outputs' {
    It 'reports missing and unscanned expected documents' {
      $script:result.MissingExpectedDocument | Should -Contain 'RepoA:Docs/RulesCompendium.md'
      $script:result.MissingExpectedDocument | Should -Contain 'Unknown:x.md'
      $script:result.MissingExpectedDocument | Should -Not -Contain 'RepoA:Docs/Guide.md'
    }

    It 'writes all four files under the first root _generated folder by default' {
      $script:result.OutputRoot | Should -Be (Join-Path (Join-Path $script:repoA '_generated') 'DocumentationOverview')
      foreach ($file in $script:result.Files.PSObject.Properties.Value) { Test-Path -LiteralPath $file | Should -BeTrue }
    }

    It 'writes a statistics page listing untitled diagrams and missing documents' {
      $stats = Get-Content -LiteralPath $script:result.Files.Statistics -Raw
      $stats | Should -Match 'Docs/Untitled\.puml'
      $stats | Should -Match 'RulesCompendium\.md'
      $stats | Should -Match '\| RepoA \| `main` \|'
    }

    It 'writes a summary whose counts match the catalog' {
      $summary = Get-Content -LiteralPath $script:result.Files.Summary -Raw | ConvertFrom-Json
      $summary.DocumentCount | Should -Be $script:catalog.Count
      $summary.EvidenceCount | Should -Be 1
    }
  }

  Context 'Safety' {
    It 'keeps Git stderr diagnostics out of revision and Unicode filename data' {
      $repo = New-TestRepository -Path (Join-Path $TestDrive 'TraceRepo') -Files @{ 'Café.md' = '# Café' }
      $priorTrace = $env:GIT_TRACE
      try {
        $env:GIT_TRACE = '1'
        $r = Build-DocumentationOverview -RepositoryRoot $repo -Confirm:$false
      }
      finally { $env:GIT_TRACE = $priorTrace }
      $summary = Get-Content -LiteralPath $r.Files.Summary -Raw | ConvertFrom-Json
      $summary.Sources[0].Branch | Should -Be 'main'
      $summary.Sources[0].Commit | Should -Match '^[0-9a-f]+$'
      $r.DocumentCount | Should -Be 1
      (Import-Csv -LiteralPath $r.Files.Catalog).Path | Should -Be 'Café.md'
    }

    It 'writes the fixed catalog header when a repository has no documents' {
      $repo = New-TestRepository -Path (Join-Path $TestDrive 'EmptyCatalog') -Files @{ 'data.txt' = 'data' }
      $r = Build-DocumentationOverview -RepositoryRoot $repo -Confirm:$false
      $r.Written | Should -BeTrue
      $r.DocumentCount | Should -Be 0
      foreach ($file in $r.Files.PSObject.Properties.Value) { Test-Path -LiteralPath $file | Should -BeTrue }
      (Get-Content -LiteralPath $r.Files.Catalog -First 1) | Should -Be '"Repository","Area","IsEvidence","Path","Type","SizeBytes","Title","FirstSentence"'
      @(Import-Csv -LiteralPath $r.Files.Catalog).Count | Should -Be 0
    }

    It 'checks angle-bracket relative links but ignores external schemes and invalid bare spaces' {
      $repo = New-TestRepository -Path (Join-Path $TestDrive 'LinkForms') -Files @{
        'README.md' = '[ok](<Rules Compendium.md>) [encoded](Rules%20Compendium.md "title") [missing](<Missing File.md>) [ftp](ftp://example.invalid/a) [vscode](vscode://file/a) [invalid](Missing Bare.md)'
        'Rules Compendium.md' = '# Rules'
      }
      $r = Build-DocumentationOverview -RepositoryRoot $repo -Confirm:$false
      $summary = Get-Content -LiteralPath $r.Files.Summary -Raw | ConvertFrom-Json
      $summary.PerRepository[0].Links | Should -Be 3
      $r.UnresolvedLinkCount | Should -Be 1
      (Import-Csv -LiteralPath $r.Files.Unresolved).Link | Should -Be 'Missing File.md'
    }

    It 'writes nothing under -WhatIf' {
      $out = Join-Path $script:repoA '_generated/WhatIfOut'
      $r = Build-DocumentationOverview -RepositoryRoot $script:repoA -OutputRoot $out -WhatIf
      $r.Written | Should -BeFalse
      Test-Path -LiteralPath $out | Should -BeFalse
    }

    It 'fails closed for a folder that is not a repository root' {
      $plain = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'NotARepo') -Force
      { Build-DocumentationOverview -RepositoryRoot $plain.FullName -WhatIf } | Should -Throw '*no .git entry*'
    }

    It 'rejects two roots for the same repository' {
      $copy = New-TestRepository -Path (Join-Path $TestDrive 'RepoA-wt-9-sprint-0002-work-items') -Files @{ 'README.md' = '# copy' }
      { Build-DocumentationOverview -RepositoryRoot $script:repoA, $copy -WhatIf } | Should -Throw '*same repository name*'
    }

    It 'rejects malformed ExpectedDocument values' {
      { Build-DocumentationOverview -RepositoryRoot $script:repoA -ExpectedDocument 'no-colon' -WhatIf } | Should -Throw
    }

    It 'rejects maintained destinations and prefix-sibling escapes without changing a sentinel' {
      $sentinel = Join-Path $script:repoA 'DocumentationCatalog.csv'
      [IO.File]::WriteAllText($sentinel, 'preserve')
      { Build-DocumentationOverview -RepositoryRoot $script:repoA -OutputRoot $script:repoA -Confirm:$false } | Should -Throw '*must be a descendant*'
      { Build-DocumentationOverview -RepositoryRoot $script:repoA -OutputRoot (Join-Path $script:repoA '_generated-other') -Confirm:$false } | Should -Throw '*must be a descendant*'
      { Build-DocumentationOverview -RepositoryRoot $script:repoA -OutputRoot (Join-Path $script:repoA '_generated/../Docs') -Confirm:$false } | Should -Throw '*must be a descendant*'
      [IO.File]::ReadAllText($sentinel) | Should -Be 'preserve'
    }

    It 'accepts an explicitly resolved artifacts descendant' {
      $out = Join-Path $env:ARTIFACTS_PATH 'Sprint0017/Task17.15.a/Ai1771/ExplicitOutput'
      $r = Build-DocumentationOverview -RepositoryRoot $script:repoA -OutputRoot $out -Confirm:$false
      $r.Written | Should -BeTrue
      Test-Path -LiteralPath $r.Files.Summary | Should -BeTrue
    }

    It 'rejects a junction redirecting a generated destination' {
      $junction = Join-Path $script:repoA '_generated/escape'
      New-Item -ItemType Junction -Path $junction -Target (Join-Path $script:repoA 'Docs') -ErrorAction Stop | Out-Null
      { Build-DocumentationOverview -RepositoryRoot $script:repoA -OutputRoot (Join-Path $junction 'out') -Confirm:$false } | Should -Throw '*reparse point*'
      Test-Path -LiteralPath (Join-Path $script:repoA 'Docs/out') | Should -BeFalse
    }

    It 'fails closed when PSFramework cannot be resolved' {
      Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Write-PSFMessage' }
      { Build-DocumentationOverview -RepositoryRoot $script:repoA -WhatIf } | Should -Throw '*requires the PSFramework command Write-PSFMessage*'
      Should -Invoke Get-Command -ParameterFilter { $Name -eq 'Write-PSFMessage' } -Times 1 -Exactly
    }
  }
}

# AI assisted using Powershell.instructions.md as guidelines
# Pester 6.2+ tests for Build-DocumentationOverview

BeforeAll {
  $functionName = 'Build-DocumentationOverview'
  $moduleName = 'ATAP.Utilities.BuildTooling.AiRendering.PowerShell'
  $environment = [Environment]::GetEnvironmentVariables('Process')
  $promoted = $environment.Contains('ATAP_PROMOTED_MODULE_MANIFEST')
  if ($promoted) {
    $manifest = [string]$environment['ATAP_PROMOTED_MODULE_MANIFEST']
    if ([string]::IsNullOrWhiteSpace($manifest) -or -not [IO.Path]::IsPathFullyQualified($manifest)) {
      throw 'The explicitly selected promoted module manifest must be an absolute file path.'
    }
    $manifestPath = (Resolve-Path -LiteralPath $manifest -ErrorAction Stop).ProviderPath
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or
      [IO.Path]::GetFileName($manifestPath) -ine "$moduleName.psd1") {
      throw "Invalid promoted module manifest: $manifestPath"
    }
    $module = Import-Module -Name $manifestPath -Force -Global -PassThru -ErrorAction Stop
    $expectedModuleBase = Split-Path -Parent $manifestPath
    $functionPath = (Resolve-Path -LiteralPath (Join-Path $expectedModuleBase "$moduleName.psm1") -ErrorAction Stop).ProviderPath
    $command = Get-Command -Name $functionName -CommandType Function -ErrorAction Stop
    if ($module.Name -ne $moduleName -or $module.ModuleBase -ne $expectedModuleBase -or
      $command.ModuleName -ne $moduleName -or $command.Module.ModuleBase -ne $expectedModuleBase -or
      $command.ScriptBlock.File -ne $functionPath) {
      throw "Test did not bind the selected promoted module: $manifestPath"
    }
  } else {
    $functionPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../public/$functionName.ps1")).ProviderPath
    . $functionPath
    if ((Get-Command -Name $functionName -CommandType Function).ScriptBlock.File -ne $functionPath) {
      throw "Test did not bind the intended source: $functionPath"
    }
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

Describe 'Build-DocumentationOverview' -Tag 'Unit' {

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
      $command = Get-Command Build-DocumentationOverview -CommandType Function
      $command.ScriptBlock.File | Should -Be $functionPath
      if ($promoted) {
        $command.ModuleName | Should -Be $moduleName
        $command.Module.ModuleBase | Should -Be $expectedModuleBase
      }
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
      $lookupScope = if ($promoted) { @{ ModuleName = $moduleName } } else { @{} }
      Mock Get-Command { $null } @lookupScope -ParameterFilter { $Name -eq 'Write-PSFMessage' }
      { Build-DocumentationOverview -RepositoryRoot $script:repoA -WhatIf } | Should -Throw '*requires the PSFramework command Write-PSFMessage*'
      Should -Invoke Get-Command @lookupScope -ParameterFilter { $Name -eq 'Write-PSFMessage' } -Times 1 -Exactly
    }
  }
}

# SIG # Begin signature block
# MIIdNwYJKoZIhvcNAQcCoIIdKDCCHSQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDxddG2WJeR5kFT
# vFZYMj/hIbt1jaqKqiSqVWA2qEoBpqCCFt0wggOfMIIDJaADAgECAgIQAzAKBggq
# hkjOPQQDAzBOMSUwIwYDVQQDDBxBVEFQIEZvdW5kYXRpb24gUm9vdCBDQSAyMDI2
# MRgwFgYDVQQKDA9BVEFQIEZvdW5kYXRpb24xCzAJBgNVBAYTAlVTMB4XDTI2MDgw
# MzE2MzQ1NloXDTI4MTEwNTE2MzQ1NlowgYAxMDAuBgNVBAMMJ0FUQVAgRm91bmRh
# dGlvbiBQb3dlclNoZWxsIENvZGUgU2lnbmluZzEYMBYGA1UECgwPQVRBUCBGb3Vu
# ZGF0aW9uMQswCQYDVQQGEwJVUzElMCMGA1UECwwcU29mdHdhcmUgUmVsZWFzZSBF
# bmdpbmVlcmluZzCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBALP0ry+i
# fJ9SLSmJ4h4JaVoQwErNIn5U/ryhOYff4uQbcd+hejmzB9QCnLZl5JGX8tn1nST7
# KGmD/4GO5JUY7ETlfNQ8j9TjJIwDg/lgtfuLThT64Acsrf4K6zYwmjRV2Jbr/9X9
# j5EXbdVSnrIL4pl3ZK57uL1zqqr4+n+BZCmjbvwSRAsin2zT5TaEC2UuewJdwPRi
# cnAV7fyT2cNBmmozd9R8OPS9w5uQsFhdq+oETHHunTFfhaVvHnPjXfJNX7QlNmDP
# vuu58yoFco7eTtZ3ynpEV3CRZW35u0Vb4lF6GK7nyDuXqvj27cuemGlGAP7mayd9
# 8OxP23OfAIcX+9obwxXFquq/0ain6Nw7NSZDOPiuLNTU1hT6RneRQeILimLqeLX8
# 3IJUQuLPhORuS/vlTXy4vSwxndiDy/nIjTp0KlgtEkgxvqakENMqxyU2Q03zfrQ+
# mXC9oqssp8eMg0jhndsus1FLvNzcSdauAsWaQdviX25HUm/HjGiam/XmTQIDAQAB
# o3UwczAdBgNVHQ4EFgQUhfEiwWt/7WJ3+RHz0i+wmAi8HT0wHwYDVR0jBBgwFoAU
# rjBQoNHV5zJw+yZwN0tHc3OKPogwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwCgYIKoZIzj0EAwMDaAAwZQIxAM0dEt4+
# jwJl6Ja+1eteTwZMLOW0fhMcTfX5G6Ez+pD0cmapdQ9dCOniaPiNzbwbcAIwLQHv
# yJOXrAQcKFVEyL1qdkbOJjCSl1wIuf1BTrdd2+CPECTtA6KwMDFf3MzbgXEpMIIF
# jTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3Qg
# Q0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJV
# UzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
# Y29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqG
# SIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3y
# ithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1If
# xp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDV
# ySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiO
# DCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQ
# jdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/
# CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCi
# EhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADM
# fRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QY
# uKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXK
# chYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t
# 9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU
# 7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6ch
# nfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8v
# Y2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0
# MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqG
# SIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi
# +IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n0
# 96wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ8
# 7PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9v
# ytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQt
# J37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMIIGtDCCBJygAwIBAgIQDces
# VwX/IZkuQEMiDDpJhjANBgkqhkiG9w0BAQsFADBiMQswCQYDVQQGEwJVUzEVMBMG
# A1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEw
# HwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMjUwNTA3MDAwMDAw
# WhcNMzgwMTE0MjM1OTU5WjBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNl
# cnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1w
# aW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAtHgx0wqYQXK+PEbAHKx126NGaHS0URedTa2NDZS1mZaDLFTt
# Q2oRjzUXMmxCqvkbsDpz4aH+qbxeLho8I6jY3xL1IusLopuW2qftJYJaDNs1+JH7
# Z+QdSKWM06qchUP+AbdJgMQB3h2DZ0Mal5kYp77jYMVQXSZH++0trj6Ao+xh/AS7
# sQRuQL37QXbDhAktVJMQbzIBHYJBYgzWIjk8eDrYhXDEpKk7RdoX0M980EpLtlrN
# yHw0Xm+nt5pnYJU3Gmq6bNMI1I7Gb5IBZK4ivbVCiZv7PNBYqHEpNVWC2ZQ8Bbfn
# FRQVESYOszFI2Wv82wnJRfN20VRS3hpLgIR4hjzL0hpoYGk81coWJ+KdPvMvaB0W
# kE/2qHxJ0ucS638ZxqU14lDnki7CcoKCz6eum5A19WZQHkqUJfdkDjHkccpL6uoG
# 8pbF0LJAQQZxst7VvwDDjAmSFTUms+wV/FbWBqi7fTJnjq3hj0XbQcd8hjj/q8d6
# ylgxCZSKi17yVp2NL+cnT6Toy+rN+nM8M7LnLqCrO2JP3oW//1sfuZDKiDEb1AQ8
# es9Xr/u6bDTnYCTKIsDq1BtmXUqEG1NqzJKS4kOmxkYp2WyODi7vQTCBZtVFJfVZ
# 3j7OgWmnhFr4yUozZtqgPrHRVHhGNKlYzyjlroPxul+bgIspzOwbtmsgY1MCAwEA
# AaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFO9vU0rp5AZ8
# esrikFb2L9RJ7MtOMB8GA1UdIwQYMBaAFOzX44LScV1kTN8uZz/nupiuHA9PMA4G
# A1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB3BggrBgEFBQcBAQRr
# MGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEF
# BQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3Rl
# ZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZn
# gQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQAXzvsWgBz+Bz0R
# dnEwvb4LyLU0pn/N0IfFiBowf0/Dm1wGc/Do7oVMY2mhXZXjDNJQa8j00DNqhCT3
# t+s8G0iP5kvN2n7Jd2E4/iEIUBO41P5F448rSYJ59Ib61eoalhnd6ywFLerycvZT
# Az40y8S4F3/a+Z1jEMK/DMm/axFSgoR8n6c3nuZB9BfBwAQYK9FHaoq2e26MHvVY
# 9gCDA/JYsq7pGdogP8HRtrYfctSLANEBfHU16r3J05qX3kId+ZOczgj5kjatVB+N
# dADVZKON/gnZruMvNYY2o1f4MXRJDMdTSlOLh0HCn2cQLwQCqjFbqrXuvTPSegOO
# zr4EWj7PtspIHBldNE2K9i697cvaiIo2p61Ed2p8xMJb82Yosn0z4y25xUbI7GIN
# /TpVfHIqQ6Ku/qjTY6hc3hsXMrS+U0yy+GWqAXam4ToWd2UQ1KYT70kZjE4YtL8P
# bzg0c1ugMZyZZd/BdHLiRu7hAWE6bTEm4XYRkA6Tl4KSFLFk43esaUeqGkH/wyW4
# N7OigizwJWeukcyIPbAvjSabnf7+Pu0VrFgoiovRDiyx3zEdmcif/sYQsfch28bZ
# eUz2rtY/9TCA6TD8dC3JE3rYkrhLULy7Dc90G6e8BlqmyIjlgp2+VqsS9/wQD7yF
# ylIz0scmbKvFoW2jNrbM1pD2T7m3XDCCBu0wggTVoAMCAQICEAhP3DNPfkVO28MP
# j/mSGDUwDQYJKoZIhvcNAQELBQAwaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRp
# Z2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVT
# dGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTAeFw0yNjA4MDUwMDAwMDBa
# Fw0zNzExMDQyMzU5NTlaMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2Vy
# dCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgU0hBMjU2IFJTQTQwOTYgVGltZXN0
# YW1wIFJlc3BvbmRlciAyMDI2IDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
# AoICAQC2e6byyf7NSvjUm0xls/04xjD4fAkOkbnGQi7+Wpx81iYxfzViaxSIctuH
# 3KSl5YEYpMuFgGsA31N2D9ATMbfZdw5uaAhuWevQKhDdZIB4NnqcfpfpWQXJiQnD
# dAElETC+bhSEvNLGbA8DtwUpFMQ4yyYQSPqomT92osQAv6hBi47ATZS6JfVWe6Xx
# hF4jJZ3iSAuf2Cros1czRSmWRHqMv9AfGZvp8ygYElhudpQjtcPpwoOl6QrZJUyV
# 3iINvN4cO05prGV0fkjG426xDr2d3z9lcSIHkdvGPdGUrXdxfVbgOUVcp2/8ISEz
# wKPW++Wa+E2ujI91EZtukGWDJ/xZ27k3oHKEXBRGfRTqjOU+jE3ba/5++JSE/7oN
# Hnjs5mekExYN96LV/mxUbCKJb8pBNY4r3uD7hEmk/M81XhVgwDA7aMzYC3LZBg9W
# Y5BMmbSay5ecmtJuXaB/0nKWmQmVZeqTVDgsmzHP5MQuhAJkiWNuC9MmCg9TZHXb
# J2/yLVSov9p16UDTLtT0+aa1vN71fHeu1qMLlLNB3WOB/ADCxr3S/1hxI92Z6jKg
# EED/btwIvbfuXkNNhg8MtDg43c4tMZae9FvqMOt/9PvmAxF9TNIsIFB8G6yb36ZJ
# ZGUL8N/pL971DyLXcK6HM5PYnH5X+eVtczhCgHCVQCF6XDAlPQIDAQABo4IBlTCC
# AZEwDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQUFMljijAu1Er7bpTz5uNAfvXszeIw
# HwYDVR0jBBgwFoAU729TSunkBnx6yuKQVvYv1Ensy04wDgYDVR0PAQH/BAQDAgeA
# MBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMIGVBggrBgEFBQcBAQSBiDCBhTAkBggr
# BgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMF0GCCsGAQUFBzAChlFo
# dHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1l
# U3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcnQwXwYDVR0fBFgwVjBUoFKg
# UIZOaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGlt
# ZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3JsMCAGA1UdIAQZMBcwCAYG
# Z4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAjcU6YR6dUgrf
# mawJgH59KECxa9Ji8sEi2g10CBDaMiqsaxWyW5cwlT/6ZF5sFznazqVsoC85U9dq
# LOYqQwst+UQQoNlDHgKRLa3xoc+OReFreFhnTXSG0Vrd2E2CZqUfm+5a+He1MJ/h
# +tNLuA+0Zzhn/Fo+FDYAHWZHx4R79ZsfRFYe9UiXpXBDf6DkUo183Y38NYmR/XfD
# Yf7YZ+oR9t3flbDwK+hgGMs0gNNp1w9Z2CyOyI5or/sSwomAuNQ0hWC9xoU4stD8
# aWsD7RkcmgVRs6vlIk3zPKQ+ylcheWkMlj+CoVRlFE55pv0ZWCaFt04lwP/rdGHE
# 9qEVQZtyRE42ox7oNgC/r+Y4bSlZ3dw9K2x1xLtu6PkPKeLBFjzKigwfqm3Hm+k/
# +lnME8F5kPZTgiy2HLEHklpryqs6QHnPXrRNeIzkAMyylnRN8P0wmirS0WkU+ywp
# EWFZ4QNg+9xS43tTuW9x0eXh7NDc1P/sV+zWxHXKH8tFt1ncHdVzqrZaYPyYMLSn
# 2TOXajveJW1L3joiQSPsWRGxkbDDW15jERFE4LvjnGu2O9zD1nLJSMdlYZEikl4w
# 2w+q4IN/R+TIe0H4ngCI1moJCTbevGH4punIxM1Uoi0nmX3ZK+XbRT01uowE5ViX
# WHng0RgsmrX/EdYUo80r3TfMlkD0/YMxggWwMIIFrAIBATBUME4xJTAjBgNVBAMM
# HEFUQVAgRm91bmRhdGlvbiBSb290IENBIDIwMjYxGDAWBgNVBAoMD0FUQVAgRm91
# bmRhdGlvbjELMAkGA1UEBhMCVVMCAhADMA0GCWCGSAFlAwQCAQUAoIGEMBgGCisG
# AQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJiX
# RSh5Yfj0qNyONkliFpvBRlSvYUBCHCwgZV9P00paMA0GCSqGSIb3DQEBAQUABIIB
# gKm/TKNLzHXU8LGhe6JuDcGvq0r3m4SrHmWz7BDOB5bYtobjK5V3AJBERktckTpz
# 73zy7HCozhCwtmmYveOYwXb3wMXFCGElenoMLPg+4k52dsiiE7tWu+7fP0YWrd2h
# pxjQtplfv+uhOick4lKT3TjRCsFRi6mCOkzpcwtzYe/BqL9jwvvsiN4X4LzOVps0
# tETGic04aN4+JmfUxjO5pHGiWntTul8WE3iHNGJ4n+VKSbHN8uLbUqp40TKwQl83
# 5W7/2OsPWoeChn9WI0us7GGZbxVUqU2LlF/pVdH8yr50jTGxGfphlvQMnSKaxkWd
# pT4wuhBLFkIHKIKs19aNEHpoIIl9UabyQ1HmXZfvxdnd+pxz456EJomZH2M2Lk+N
# 13HnV9gpE+UOx4RSgTWbglJGOxZFk6ATcgDXLGuVsX0MEBdP51JZtP9kJ9bWKGma
# f5H/SFCHtrCLQm2QJ6lc+fjDuR/0Bv09YC2Bvjc36Lm8L9/CE2F0DDFz/ePT3K+b
# m6GCAyYwggMiBgkqhkiG9w0BCQYxggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVT
# MRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1
# c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAhP
# 3DNPfkVO28MPj/mSGDUwDQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJ
# KoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yNjExMDUwMjIyMThaMC8GCSqGSIb3
# DQEJBDEiBCAN0uIAvyGVA4WWGrhNBMcvGC4GQNu3LPgXMpf3dZtGYDANBgkqhkiG
# 9w0BAQEFAASCAgCVl0I7mrm2p3zcYHT97gBJroN6ChkY/TzxeBsR0MTSozK6d9lv
# fX915l9vPW8PG+kADvgznySxsqX65AHtjhUdSenhcqTB7aSGQC8wnj5s5mS6fbra
# c+3Cb/zrl4p0oLJvj9DFJC8Kk/SuUwbygvY91CarZvHiz+oDBh/CT8qL9TAr8j5/
# qeWfwG1IsB18baV63OcAGMpJZ9xJ/FVwxBC2kzySdOFFmMay1aehcn5zWZQKBybX
# fVL5xrvCsPRnPFKY8NWGWfeH4IsDha8NsvOnCXd/Yba3wrTE0xBVMHmjToPGTNoj
# gn0Zk2erQorIdbfNnkPk2wDLFP5zX8IJMsvGBcqfzaJztAsu/MVhUQ80K39qp2/8
# D65XB3f8Bd3oGUHWuKBxxsLx4ODKauoKLooQlMOeyXt99nS5LSyTKQu9gUqnK/Aw
# PO/HzvnPR5HyRrA0dolyHyajzLYhl9XhZOBBNgGx4O5r753KmcBbd8n8i3+IyVVc
# IA9ZKvDyqNSwjg80WhoP5WDy3Zcgl1tA5ps5oZEVVkV3zg5cQSRLKGA/vFufetIm
# gurHGtz5xaTyrFXGtPHl9kDvIdQXZIUdI3qXRc0TtUDJaX44vXylxU+1j5DAInaN
# 4d75GnVTQfBerzhLcw8sSAbw/3TIVAB+s4y7kAiW2OGae44yPktro2CWug==
# SIG # End signature block

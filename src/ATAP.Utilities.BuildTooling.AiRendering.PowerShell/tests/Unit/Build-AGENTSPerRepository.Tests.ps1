BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([Parameter(ValueFromRemainingArguments = $true)] $Rest)
    }
  }
  # Task 14.60: the combiner now builds the core body through this helper instead of
  # reading <Carrier>-base.md directly, so the unit fixture must load it too.
  . "$PSScriptRoot\..\..\private\Get-AICoreInstructionBody.ps1"
  . "$PSScriptRoot\..\..\public\Build-AGENTSPerRepository.ps1"
}

AfterAll {
  Remove-Item Function:\Write-PSFMessage -Force -ErrorAction SilentlyContinue
}

Describe 'Build-AGENTSPerRepository [public]' -Tag 'Unit' {
  BeforeEach {
    $script:evidenceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../_generated/Sprint0017/17.9.b/AGENTSLF/fixtures'))
    $script:testRoot = Join-Path $script:evidenceRoot ([guid]::NewGuid().ToString('N'))
    if (-not $script:testRoot.StartsWith($script:evidenceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'AGENTS fixture escaped its owning evidence directory.'
    }
    $script:sharedRoot = Join-Path $script:testRoot 'SharedVSCode-wt-56-Sprint-0013-work-items'
    $script:repoRoot = Join-Path $script:testRoot 'ATAP.Utilities-wt-123-Sprint-0013-work-items'
    New-Item -ItemType Directory -Path $script:sharedRoot, $script:repoRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $script:sharedRoot 'AGENTS-base.md') -Value "# Shared core`n" -NoNewline
    Set-Content -LiteralPath (Join-Path $script:repoRoot 'ai-local.md') -Value "# Local rules`n" -NoNewline
    $script:context = [pscustomobject]@{
      WorkspacePath = Join-Path $script:testRoot 'OverviewSprint0013.code-workspace'
      SharedVSCodePath = $script:sharedRoot
      SprintWorktreePattern = '-wt-\d+-Sprint-\d{4}-work-items$'
      Repositories = @(
        [pscustomobject]@{
          Repository = 'ATAP.Utilities-wt-123-Sprint-0013-work-items'
          Path = $script:repoRoot
          Skipped = $false
          ResolutionError = $null
        }
      )
    }
  }

  It 'combines the local and shared core blocks idempotently' {
    $first = Build-AGENTSPerRepository -RepositoryContext $script:context -Confirm:$false
    $second = Build-AGENTSPerRepository -RepositoryContext $script:context -Confirm:$false
    $content = Get-Content -LiteralPath (Join-Path $script:repoRoot 'AGENTS.md') -Raw

    $first.Success | Should -BeTrue
    $second.Success | Should -BeTrue
    $content | Should -Match '<!-- AI-LOCAL:BEGIN -->'
    $content | Should -Match '# Local rules'
    $content | Should -Match '<!-- AI-CORE:BEGIN -->'
    $content | Should -Match '# Shared core'
  }

  Context 'AI-AGENT-CODEX block (Task 13.76.b)' {
    BeforeEach {
      $script:codexPath = Join-Path $script:sharedRoot '.ai/core/agent-specific/codex.md'
      New-Item -ItemType Directory -Path (Split-Path $script:codexPath -Parent) -Force | Out-Null
      # Keep the absent/empty cases explicit even though each test owns a unique fixture.
      Remove-Item -LiteralPath $script:codexPath -Force -ErrorAction SilentlyContinue
    }

    It 'appends the Codex body after AI-CORE and stays idempotent' {
      Set-Content -LiteralPath $script:codexPath -Value "## Codex`n`nEscalate first.`n" -NoNewline

      $first = Build-AGENTSPerRepository -RepositoryContext $script:context -Confirm:$false
      $second = Build-AGENTSPerRepository -RepositoryContext $script:context -Confirm:$false
      $content = Get-Content -LiteralPath (Join-Path $script:repoRoot 'AGENTS.md') -Raw

      $first.HasCodexAgentInstructions | Should -BeTrue
      $first.RepositoryResults[0].HasCodexBlock | Should -BeTrue
      $second.RepositoryResults[0].Action | Should -Be 'unchanged'

      $content | Should -Match '# Shared core'
      $content | Should -Match 'Escalate first'
      # Codex must come after core, never in place of it (the 2026-07-25 clobber).
      $content.IndexOf('<!-- AI-CORE:END -->') |
        Should -BeLessThan $content.IndexOf('<!-- AI-AGENT-CODEX:BEGIN -->')
      ([regex]::Matches($content, [regex]::Escape('<!-- AI-AGENT-CODEX:BEGIN -->'))).Count | Should -Be 1
    }

    It 'omits the block when the canonical Codex file is absent' {
      $result = Build-AGENTSPerRepository -RepositoryContext $script:context -Confirm:$false

      $result.HasCodexAgentInstructions | Should -BeFalse
      (Get-Content -LiteralPath (Join-Path $script:repoRoot 'AGENTS.md') -Raw) |
        Should -Not -Match 'AI-AGENT-CODEX'
    }

    It 'omits the block when the canonical Codex file is whitespace only' {
      Set-Content -LiteralPath $script:codexPath -Value "  `n" -NoNewline

      $result = Build-AGENTSPerRepository -RepositoryContext $script:context -Confirm:$false

      $result.HasCodexAgentInstructions | Should -BeFalse
      (Get-Content -LiteralPath (Join-Path $script:repoRoot 'AGENTS.md') -Raw) |
        Should -Not -Match 'AI-AGENT-CODEX'
    }
  }

  Context 'LF section composition (SC-0472)' {
    BeforeEach {
      $script:codexPath = Join-Path $script:sharedRoot '.ai/core/agent-specific/codex.md'
      New-Item -ItemType Directory -Path (Split-Path $script:codexPath -Parent) -Force | Out-Null
      $script:expectedContent = @(
        '<!-- AI-LOCAL:BEGIN -->'
        '# Local rules'
        'local café  '
        'local end'
        '<!-- AI-LOCAL:END -->'
        '<!-- AI-CORE:BEGIN -->'
        '# Shared core'
        'core λ  '
        'core end'
        '<!-- AI-CORE:END -->'
        '<!-- AI-AGENT-CODEX:BEGIN -->'
        '## Codex'
        'codex café  '
        'codex end'
        '<!-- AI-AGENT-CODEX:END -->'
        ''
      ) -join "`n"
    }

    It 'preserves normalized section content and does not rewrite <Name> input on a second run' -ForEach @(
      @{
        Name = 'CRLF'
        Local = "# Local rules`r`nlocal café  `r`nlocal end`r`n"
        Core = "# Shared core`r`ncore λ  `r`ncore end`r`n"
        Codex = "## Codex`r`ncodex café  `r`ncodex end`r`n"
      }
      @{
        Name = 'LF'
        Local = "# Local rules`nlocal café  `nlocal end`n"
        Core = "# Shared core`ncore λ  `ncore end`n"
        Codex = "## Codex`ncodex café  `ncodex end`n"
      }
      @{
        Name = 'mixed CRLF, LF and lone CR'
        Local = "# Local rules`r`nlocal café  `rlocal end`n"
        Core = "# Shared core`ncore λ  `r`ncore end`r"
        Codex = "## Codex`rcodex café  `ncodex end`r`n"
      }
    ) {
      param($Name, $Local, $Core, $Codex)

      $inputPaths = @(
        (Join-Path $script:repoRoot 'ai-local.md')
        (Join-Path $script:sharedRoot 'AGENTS-base.md')
        $script:codexPath
      )
      $encoding = [Text.UTF8Encoding]::new($false)
      [IO.File]::WriteAllText($inputPaths[0], $Local, $encoding)
      [IO.File]::WriteAllText($inputPaths[1], $Core, $encoding)
      [IO.File]::WriteAllText($inputPaths[2], $Codex, $encoding)
      $inputHashes = @($inputPaths | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash })

      $first = Build-AGENTSPerRepository -RepositoryContext $script:context -Confirm:$false
      $outputPath = Join-Path $script:repoRoot 'AGENTS.md'
      $bytes = [IO.File]::ReadAllBytes($outputPath)

      $first.Success | Should -BeTrue
      $first.RepositoryResults[0].Action | Should -Be 'written'
      $bytes | Should -Not -Contain ([byte]13)
      ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
      [Text.Encoding]::UTF8.GetString($bytes) | Should -BeExactly $script:expectedContent
      [Convert]::ToBase64String($bytes) | Should -BeExactly ([Convert]::ToBase64String($encoding.GetBytes($script:expectedContent)))

      $unchangedTime = [datetime]::new(2001, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
      [IO.File]::SetLastWriteTimeUtc($outputPath, $unchangedTime)
      $second = Build-AGENTSPerRepository -RepositoryContext $script:context -Confirm:$false

      $second.Success | Should -BeTrue
      $second.RepositoryResults[0].Action | Should -Be 'unchanged'
      [IO.File]::GetLastWriteTimeUtc($outputPath) | Should -Be $unchangedTime
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($outputPath)) | Should -BeExactly ([Convert]::ToBase64String($bytes))
      @($inputPaths | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash }) | Should -Be $inputHashes
    }

    It 'repairs an existing mixed-ending composition before accepting it as unchanged' {
      $local = "# Local rules`r`nlocal café  `rlocal end`n"
      $core = "# Shared core`ncore λ  `r`ncore end`r"
      $codex = "## Codex`rcodex café  `ncodex end`r`n"
      $encoding = [Text.UTF8Encoding]::new($false)
      [IO.File]::WriteAllText((Join-Path $script:repoRoot 'ai-local.md'), $local, $encoding)
      [IO.File]::WriteAllText((Join-Path $script:sharedRoot 'AGENTS-base.md'), $core, $encoding)
      [IO.File]::WriteAllText($script:codexPath, $codex, $encoding)
      $outputPath = Join-Path $script:repoRoot 'AGENTS.md'
      # Seed the old composer's exact output: LF sentinels around unnormalized bodies.
      $oldContent = @(
        '<!-- AI-LOCAL:BEGIN -->', $local.TrimEnd(), '<!-- AI-LOCAL:END -->'
        '<!-- AI-CORE:BEGIN -->', $core.TrimEnd(), '<!-- AI-CORE:END -->'
        '<!-- AI-AGENT-CODEX:BEGIN -->', $codex.TrimEnd(), '<!-- AI-AGENT-CODEX:END -->', ''
      ) -join "`n"
      [IO.File]::WriteAllText($outputPath, $oldContent, $encoding)

      $result = Build-AGENTSPerRepository -RepositoryContext $script:context -Confirm:$false
      $bytes = [IO.File]::ReadAllBytes($outputPath)

      $result.Success | Should -BeTrue
      $result.RepositoryResults[0].Action | Should -Be 'written'
      $bytes | Should -Not -Contain ([byte]13)
      ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
      [Text.Encoding]::UTF8.GetString($bytes) | Should -BeExactly $script:expectedContent
    }
  }
}

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([Parameter(ValueFromRemainingArguments = $true)] $Rest)
    }
  }
  . "$PSScriptRoot\..\..\public\Build-AGENTSPerRepository.ps1"
}

AfterAll {
  Remove-Item Function:\Write-PSFMessage -Force -ErrorAction SilentlyContinue
}

Describe 'Build-AGENTSPerRepository [public]' -Tag 'Unit' {
  BeforeEach {
    $script:testRoot = Join-Path $TestDrive 'agents'
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
      # $TestDrive is shared across Its in this file, so a codex.md written by an earlier
      # test would leak into the absent/empty cases.
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
}

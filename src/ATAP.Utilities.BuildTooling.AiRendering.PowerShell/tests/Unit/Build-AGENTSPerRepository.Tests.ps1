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
}

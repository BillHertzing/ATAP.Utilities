BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  . "$PSScriptRoot\..\..\public\Build-AgentSpecificPerRepository.ps1"
}

AfterAll {
  Remove-Item -Path 'Function:\Write-PSFMessage' -Force -ErrorAction SilentlyContinue
}

Describe 'Build-AgentSpecificPerRepository [public]' -Tag 'Unit' {
  BeforeEach {
    $script:gitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "agent_specific_$([guid]::NewGuid().ToString('N'))"
    $script:sharedSprint = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot 'SharedVSCode-wt-48-Sprint-0010-work-items') -Force
    $script:repoSprint = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot 'ATAP.Utilities-wt-115-Sprint-0010-work-items') -Force
    $script:planningSprint = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot '_Planning-wt-20-Sprint-0010-work-items') -Force
    $script:stableOnly = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot 'AceCommander') -Force
    New-Item -ItemType Directory -Path (Join-Path $script:sharedSprint '.github') -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $script:sharedSprint 'GEMINI.md') -Value "# Gemini delta`nCore instructions live in AGENTS.md.`n" -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath (Join-Path $script:sharedSprint '.github\copilot-instructions.md') -Value "# Copilot delta`nCore instructions live in AGENTS.md.`n" -Encoding UTF8 -NoNewline

    $script:workspacePath = Join-Path $script:gitRoot 'OverviewSprint0010.code-workspace'
    @{
      folders        = @(
        @{ path = $script:sharedSprint.Name }
        @{ path = $script:repoSprint.Name }
        @{ path = $script:planningSprint.Name }
        @{ path = $script:stableOnly.Name }
      )
      sprintEphemeral = @{ sprintNumber = '0010' }
    } |
      ConvertTo-Json -Depth 10 |
      Set-Content -LiteralPath $script:workspacePath -Encoding UTF8
  }

  AfterEach {
    Remove-Item -LiteralPath $script:gitRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'copies both agent-specific files and skips stable-only repositories' {
    $result = Build-AgentSpecificPerRepository `
      -WorktreeRoot $script:planningSprint.FullName `
      -WorkspacePath $script:workspacePath `
      -Confirm:$false

    $result.Success | Should -BeTrue
    foreach ($relativePath in @('GEMINI.md', '.github\copilot-instructions.md')) {
      $destination = Join-Path $script:repoSprint $relativePath
      Test-Path -LiteralPath $destination | Should -BeTrue
      (Get-Content -LiteralPath $destination -Raw) |
        Should -BeExactly (Get-Content -LiteralPath (Join-Path $script:sharedSprint $relativePath) -Raw)
      Test-Path -LiteralPath (Join-Path $script:stableOnly $relativePath) | Should -BeFalse
    }

    ($result.RepositoryResults | Where-Object Repository -eq $script:stableOnly.Name).Skipped | Should -BeTrue
  }

  It 'reports unchanged and preserves hashes on a second run' {
    $first = Build-AgentSpecificPerRepository `
      -WorktreeRoot $script:planningSprint.FullName `
      -WorkspacePath $script:workspacePath `
      -Confirm:$false
    $first.Success | Should -BeTrue

    $geminiPath = Join-Path $script:repoSprint 'GEMINI.md'
    $beforeHash = (Get-FileHash -LiteralPath $geminiPath -Algorithm SHA256).Hash
    $beforeTime = (Get-Item -LiteralPath $geminiPath).LastWriteTimeUtc

    Start-Sleep -Milliseconds 1100
    $second = Build-AgentSpecificPerRepository `
      -WorktreeRoot $script:planningSprint.FullName `
      -WorkspacePath $script:workspacePath `
      -Confirm:$false

    $repo = $second.RepositoryResults | Where-Object Repository -eq $script:repoSprint.Name
    @($repo.Files | Select-Object -ExpandProperty Action -Unique) | Should -Be @('unchanged')
    (Get-FileHash -LiteralPath $geminiPath -Algorithm SHA256).Hash | Should -Be $beforeHash
    (Get-Item -LiteralPath $geminiPath).LastWriteTimeUtc | Should -Be $beforeTime
  }

  It 'rejects an agent-specific base that duplicates the shared core body' {
    Set-Content -LiteralPath (Join-Path $script:sharedSprint 'GEMINI.md') `
      -Value "<!--`nSourceId: ai.core.main-instructions.v1`n-->`n# duplicated core`n" `
      -Encoding UTF8 `
      -NoNewline

    {
      Build-AgentSpecificPerRepository `
        -WorktreeRoot $script:planningSprint.FullName `
        -WorkspacePath $script:workspacePath `
        -Confirm:$false
    } | Should -Throw '*no-double-core invariant*'
  }
}

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  # This orchestrator fans out to the per-carrier combiners by name. Load them - and the
  # Task 14.60 core-body helper they now depend on - explicitly rather than relying on a
  # sibling test file having dot-sourced them into the shared session first, which is
  # ordering-dependent and silently changes what this test actually exercises.
  . "$PSScriptRoot\..\..\private\Get-AICoreInstructionBody.ps1"
  . "$PSScriptRoot\..\..\public\Build-CLAUDEPerRepository.ps1"
  . "$PSScriptRoot\..\..\public\Build-AGENTSPerRepository.ps1"
  . "$PSScriptRoot\..\..\public\Build-AIInstructionsPerRepository.ps1"
}

AfterAll {
  Remove-Item -Path 'Function:\Write-PSFMessage' -Force -ErrorAction SilentlyContinue
}

Describe 'Build-AIInstructionsPerRepository [public]' -Tag 'Unit' {
  BeforeEach {
    $script:gitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ai_instructions_$([guid]::NewGuid().ToString('N'))"
    $script:sharedSprint = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot 'SharedVSCode-wt-48-Sprint-0010-work-items') -Force
    $script:repoSprint = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot 'ATAP.Utilities-wt-115-Sprint-0010-work-items') -Force
    $script:planningSprint = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot '_Planning-wt-20-Sprint-0010-work-items') -Force
    $script:stableOnly = New-Item -ItemType Directory -Path (Join-Path $script:gitRoot 'AceCommander') -Force
    New-Item -ItemType Directory -Path (Join-Path $script:sharedSprint '.github') -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $script:sharedSprint 'CLAUDE-base.md') -Value "# Claude core`n" -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath (Join-Path $script:sharedSprint 'AGENTS-base.md') -Value "# Shared core`n" -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath (Join-Path $script:sharedSprint 'GEMINI.md') -Value "# Gemini delta`nCore instructions live in AGENTS.md.`n" -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath (Join-Path $script:sharedSprint '.github\copilot-instructions.md') -Value "# Copilot delta`nCore instructions live in AGENTS.md.`n" -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath (Join-Path $script:repoSprint 'ai-local.md') -Value "# Repo local`n" -Encoding UTF8 -NoNewline

    $script:workspacePath = Join-Path $script:gitRoot 'OverviewSprint0010.code-workspace'
    @{
      folders        = @(
        @{ path = $script:sharedSprint.Name }
        @{ path = $script:repoSprint.Name }
        @{ path = $script:planningSprint.Name }
        @{ path = $script:stableOnly.Name }
      )
      sprintEphemeral = @{ sprintNumber = '0010' }
      sprintInfrastructure = @{
        buildMasterBaseUrl = 'https://utat022:50017'
        proGetBaseUrl      = 'https://utat022:50000'
      }
    } |
      ConvertTo-Json -Depth 10 |
      Set-Content -LiteralPath $script:workspacePath -Encoding UTF8
  }

  AfterEach {
    Remove-Item -LiteralPath $script:gitRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'walks the workspace once, fans out all lanes, and aggregates per-repository results' {
    $result = Build-AIInstructionsPerRepository `
      -WorktreeRoot $script:repoSprint.FullName `
      -WorkspacePath $script:workspacePath `
      -Confirm:$false

    $result.Success | Should -BeTrue
    $result.Builders.Claude | Should -Not -BeNullOrEmpty
    $result.Builders.Agents | Should -Not -BeNullOrEmpty
    $result.Builders.AgentSpecific | Should -Not -BeNullOrEmpty
    $result.WorkspaceReadCount | Should -Be 1
    $result.RepositoriesDiscovered | Should -Be 4
    $result.RepositoriesSkipped | Should -Be 1

    foreach ($relativePath in @('CLAUDE.md', 'AGENTS.md', 'GEMINI.md', '.github\copilot-instructions.md')) {
      Test-Path -LiteralPath (Join-Path $script:repoSprint $relativePath) | Should -BeTrue
      Test-Path -LiteralPath (Join-Path $script:stableOnly $relativePath) | Should -BeFalse
    }

    $repoResult = $result.RepositoryResults | Where-Object Repository -eq $script:repoSprint.Name
    $repoResult.Success | Should -BeTrue
    $repoResult.Skipped | Should -BeFalse
    $repoResult.Lanes.Claude.Success | Should -BeTrue
    $repoResult.Lanes.Agents.Success | Should -BeTrue
    $repoResult.Lanes.AgentSpecific.Files.Count | Should -Be 2

    $stableResult = $result.RepositoryResults | Where-Object Repository -eq $script:stableOnly.Name
    $stableResult.Success | Should -BeTrue
    $stableResult.Skipped | Should -BeTrue
  }

  It 'is a no-op on a second run when the bases and local overlay are unchanged' {
    $first = Build-AIInstructionsPerRepository `
      -WorktreeRoot $script:repoSprint.FullName `
      -WorkspacePath $script:workspacePath `
      -Confirm:$false
    $first.Success | Should -BeTrue

    $paths = @(
      (Join-Path $script:repoSprint 'CLAUDE.md')
      (Join-Path $script:repoSprint 'AGENTS.md')
      (Join-Path $script:repoSprint 'GEMINI.md')
      (Join-Path $script:repoSprint '.github\copilot-instructions.md')
    )
    $beforeHashes = @{}
    $beforeTimes = @{}
    foreach ($path in $paths) {
      $beforeHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
      $beforeTimes[$path] = (Get-Item -LiteralPath $path).LastWriteTimeUtc
    }

    Start-Sleep -Milliseconds 1100
    $second = Build-AIInstructionsPerRepository `
      -WorktreeRoot $script:repoSprint.FullName `
      -WorkspacePath $script:workspacePath `
      -Confirm:$false

    $second.Success | Should -BeTrue
    $repo = $second.RepositoryResults | Where-Object Repository -eq $script:repoSprint.Name
    $repo.Lanes.Claude.Action | Should -Be 'unchanged'
    $repo.Lanes.Agents.Action | Should -Be 'unchanged'
    @($repo.Lanes.AgentSpecific.Files | Select-Object -ExpandProperty Action -Unique) | Should -Be @('unchanged')

    foreach ($path in $paths) {
      (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash | Should -Be $beforeHashes[$path]
      (Get-Item -LiteralPath $path).LastWriteTimeUtc | Should -Be $beforeTimes[$path]
    }
  }

  It 'returns an error aggregate when the workspace contains no SharedVSCode folder' {
    @{
      folders        = @(@{ path = $script:repoSprint.Name })
      sprintEphemeral = @{ sprintNumber = '0010' }
    } |
      ConvertTo-Json -Depth 10 |
      Set-Content -LiteralPath $script:workspacePath -Encoding UTF8

    $result = Build-AIInstructionsPerRepository `
      -WorktreeRoot $script:repoSprint.FullName `
      -WorkspacePath $script:workspacePath `
      -Confirm:$false

    $result.Success | Should -BeFalse
    $result.Errors -join ' ' | Should -Match 'exactly one SharedVSCode'
  }
}

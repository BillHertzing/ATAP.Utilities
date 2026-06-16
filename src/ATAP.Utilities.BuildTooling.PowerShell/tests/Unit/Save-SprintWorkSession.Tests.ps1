# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ tests for Save-SprintWorkSession — V4-H05 hardening
# Verifies that direct import without full dependency stack (no global:settings,
# no Get-PVal) does NOT emit noisy non-terminating errors when defaults are usable.

BeforeAll {
  $functionName = 'Save-SprintWorkSession'

  # Always dot-source from the source tree to ensure we test the actual file.
  $functionPath = Join-Path $PSScriptRoot '..\..\public\Save-SprintWorkSession.ps1'
  if (-not (Test-Path $functionPath)) {
    throw "Function file not found: $functionPath"
  }

  # PSFramework must be importable so Write-PSFMessage no-ops cleanly in a
  # sparse environment; if it isn't available the test still runs without it.
  if (-not (Get-Module -Name PSFramework -ErrorAction SilentlyContinue)) {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }

  $script:realGitPath = (Get-Command git.exe -CommandType Application -ErrorAction Stop).Source
  function global:git {
    param([Parameter(ValueFromRemainingArguments = $true)]$Arguments)
    & $script:realGitPath @Arguments
  }

  # Build an isolated temp tree that mimics a real sprint layout:
  #   <gitRoot>/
  #     ATAP.Utilities-wt-100-sprint-0007-work-items/   <- git repo
  #     _Planning-wt-14-sprint-0007-work-items/          <- planning root
  $script:gitRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ssws-test-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:gitRoot -Force | Out-Null

  $script:sprintNumber = '0007'
  $script:atapWt = Join-Path $script:gitRoot "ATAP.Utilities-wt-100-sprint-$($script:sprintNumber)-work-items"
  $script:planningWt = Join-Path $script:gitRoot "_Planning-wt-14-sprint-$($script:sprintNumber)-work-items"
  New-Item -ItemType Directory -Path $script:atapWt, $script:planningWt -Force | Out-Null

  # Initialise a git repo in the ATAP worktree so branch detection works.
  $branchName = "100-sprint-$($script:sprintNumber)-work-items"
  & git -C $script:atapWt init --quiet --initial-branch=$branchName 2>$null
  & git -C $script:atapWt config user.email 'test@example.com'
  & git -C $script:atapWt config user.name 'Pester Tester'
  Set-Content -LiteralPath (Join-Path $script:atapWt 'README.md') -Value 'seed' -Encoding UTF8
  & git -C $script:atapWt add . 2>$null | Out-Null
  & git -C $script:atapWt commit --quiet -m 'seed' 2>$null | Out-Null

  # Create a fake Claude projects dir with a JSONL session file for the slug
  # that corresponds to $script:atapWt.
  $slug = ($script:atapWt.Substring(0, 1).ToLower() + $script:atapWt.Substring(1)) `
    -replace ':', '-' -replace '\\', '-' -replace '_', '-' -replace '\.', '-' -replace '^-', ''
  $script:claudeProjectsRoot = Join-Path $script:gitRoot '.claude-projects'
  $sessionDir = Join-Path $script:claudeProjectsRoot $slug
  New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null
  $jsonlPath = Join-Path $sessionDir 'fake-session.jsonl'
  Set-Content -LiteralPath $jsonlPath -Value '{"role":"user","content":"test"}' -Encoding UTF8
  $memoryDir = Join-Path $sessionDir 'memory'
  New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $memoryDir 'memory-note.md') -Value '# memory' -Encoding UTF8

  function global:7z {
    param(
      [string]$Action,
      [string]$ArchivePath,
      [string]$SourcePath
    )

    if ($Action -ne 'a') {
      throw "Unexpected 7z action: $Action"
    }

    New-Item -ItemType Directory -Path (Split-Path -Path $ArchivePath -Parent) -Force | Out-Null
    Set-Content -LiteralPath $ArchivePath -Value "mock archive for $SourcePath" -Encoding UTF8
  }

  # Re-dot-source after the temp tree is ready.
  . $functionPath
}

AfterAll {
  if (Test-Path -LiteralPath 'Function:\git') {
    Remove-Item -LiteralPath 'Function:\git' -ErrorAction SilentlyContinue
  }
  if (Test-Path -LiteralPath 'Function:\7z') {
    Remove-Item -LiteralPath 'Function:\7z' -ErrorAction SilentlyContinue
  }
  if (Test-Path $script:gitRoot) {
    Remove-Item -Recurse -Force $script:gitRoot -ErrorAction SilentlyContinue
  }
}

Describe 'Save-SprintWorkSession' {

  It 'function is loaded after dot-sourcing' {
    Get-Command -Name 'Save-SprintWorkSession' -CommandType Function |
      Should -Not -BeNullOrEmpty
  }

  Context 'sparse environment — no global:settings, default parameter values' {

    It 'does NOT emit non-terminating errors when called with explicit parameters' {
      # Save-SprintWorkSession computes the session slug from (Get-Location).Path so we must
      # cd into the fake atap worktree to match the JSONL we seeded there.
      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        $savedSettings = $global:settings
        try {
          $global:settings = $null

          $errorMessages = @()
          Save-SprintWorkSession `
            -SprintN $script:sprintNumber `
            -PlanningRoot $script:planningWt `
            -ClaudeProjectsRoot $script:claudeProjectsRoot `
            -GitHubRoot $script:gitRoot `
            -WhatIf `
            -ErrorVariable ev `
            -ErrorAction SilentlyContinue

          $ev | ForEach-Object { $errorMessages += $_.Exception.Message }
          $errorMessages | Should -BeNullOrEmpty -Because 'defaults are usable; no errors expected'
        } finally {
          $global:settings = $savedSettings
        }
      } finally {
        Set-Location $savedLocation
      }
    }

    It 'does NOT emit non-terminating errors when Get-PVal helper is unavailable' {
      # Simulate a sparse import: remove Get-PVal from session scope and verify
      # the function still runs cleanly using its parameter-declaration defaults.
      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        $savedSettings = $global:settings
        $getPValWasAvailable = $false
        try {
          $global:settings = $null

          if (Test-Path -LiteralPath 'Function:\Get-PVal') {
            Remove-Item -LiteralPath 'Function:\Get-PVal' -ErrorAction SilentlyContinue
            $getPValWasAvailable = $true
          }
          if (Test-Path -LiteralPath 'Function:\Get-ParameterValueFromNeoConfigurationRoot') {
            Remove-Item -LiteralPath 'Function:\Get-ParameterValueFromNeoConfigurationRoot' -ErrorAction SilentlyContinue
          }

          $errorMessages = @()
          Save-SprintWorkSession `
            -SprintN $script:sprintNumber `
            -PlanningRoot $script:planningWt `
            -ClaudeProjectsRoot $script:claudeProjectsRoot `
            -GitHubRoot $script:gitRoot `
            -WhatIf `
            -ErrorVariable ev `
            -ErrorAction SilentlyContinue

          $ev | ForEach-Object { $errorMessages += $_.Exception.Message }
          $errorMessages | Should -BeNullOrEmpty -Because 'parameter defaults are usable; Get-PVal absence must not cause errors'
        } finally {
          $global:settings = $savedSettings
          # Re-load Get-PVal if it was available before this test
          if ($getPValWasAvailable) {
            $getPValPath = Join-Path $PSScriptRoot '..\..\..\..\ATAP.Utilities.PowerShell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
            if (Test-Path $getPValPath) { . $getPValPath }
          }
        }
      } finally {
        Set-Location $savedLocation
      }
    }
  }

  Context 'Bug 2 — slug fallback: stable-repo slug when sprint-worktree slug has no JSONL' {

    It 'falls back to stable slug when sprint-worktree slug directory has no JSONL' {
      # Build a custom ClaudeProjectsRoot that has a JSONL ONLY at the stable slug.
      # The sprint worktree slug directory is absent so the function must fall back.
      $customClaudeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ssws-slug-' + [guid]::NewGuid().ToString('N'))
      $customPlanRoot   = Join-Path ([System.IO.Path]::GetTempPath()) ('ssws-plan-' + [guid]::NewGuid().ToString('N'))

      # Compute the stable slug by stripping -wt-.+$ from the actual sprint worktree path.
      # Use the real temp sprint worktree created in BeforeAll (it exists and carries a
      # '-wt-' segment) so Set-Location succeeds regardless of which sprint we are in.
      $actualWt   = $script:atapWt
      $stableCwd  = $actualWt -replace '-wt-.+$', ''  # <gitRoot>\ATAP.Utilities
      $stableSlug = ($stableCwd.Substring(0, 1).ToLower() + $stableCwd.Substring(1)) `
          -replace ':', '-' -replace '\\', '-' -replace '_', '-' -replace '\.', '-' -replace '^-', ''

      $stableSessionDir = Join-Path $customClaudeRoot $stableSlug
      New-Item -ItemType Directory -Path $stableSessionDir, $customPlanRoot -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $stableSessionDir 'stable.jsonl') `
          -Value '{"role":"user","content":"stable"}' -Encoding UTF8

      $savedLocation = Get-Location
      Set-Location $actualWt
      try {
        $savedSettings = $global:settings
        try {
          $global:settings = $null

          $errorMessages = @()
          Save-SprintWorkSession `
            -SprintN '0008' `
            -PlanningRoot $customPlanRoot `
            -ClaudeProjectsRoot $customClaudeRoot `
            -GitHubRoot 'C:\Dropbox\whertzing\GitHub' `
            -WhatIf `
            -ErrorVariable ev `
            -ErrorAction SilentlyContinue

          $ev | ForEach-Object { $errorMessages += $_.Exception.Message }
          $errorMessages | Should -BeNullOrEmpty -Because 'stable slug fallback should find the JSONL silently'
        } finally {
          $global:settings = $savedSettings
        }
      } finally {
        Set-Location $savedLocation
        Remove-Item -Recurse -Force $customClaudeRoot, $customPlanRoot -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'auto-detection — branch name and planning worktree resolution' {

    It 'auto-detects sprint number from branch name matching ^\d+-sprint-(\d{4})' {
      # cd into the fake ATAP worktree so git rev-parse reads the fake branch and
      # slug computation points to our seeded JSONL.
      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        $savedSettings = $global:settings
        try {
          $global:settings = $null

          $errorMessages = @()
          # Do not pass -SprintN; rely on auto-detection from git branch
          Save-SprintWorkSession `
            -PlanningRoot $script:planningWt `
            -ClaudeProjectsRoot $script:claudeProjectsRoot `
            -GitHubRoot $script:gitRoot `
            -WhatIf `
            -ErrorVariable ev `
            -ErrorAction SilentlyContinue

          $ev | ForEach-Object { $errorMessages += $_.Exception.Message }
          $errorMessages | Should -BeNullOrEmpty -Because 'branch name carries a valid sprint number'
        } finally {
          $global:settings = $savedSettings
        }
      } finally {
        Set-Location $savedLocation
      }
    }

    It 'auto-resolves _Planning sprint worktree from GitHubRoot' {
      # cd into the fake ATAP worktree so (Split-Path -Parent (Get-Location).Path)
      # resolves to $script:gitRoot (not the real GitHub folder), keeping the
      # planning-search results isolated to our temp tree.
      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        $savedSettings = $global:settings
        try {
          $global:settings = $null

          # Passing GitHubRoot=$script:gitRoot; the function should find
          # _Planning-wt-14-sprint-0007-work-items automatically.
          $errorMessages = @()
          Save-SprintWorkSession `
            -SprintN $script:sprintNumber `
            -ClaudeProjectsRoot $script:claudeProjectsRoot `
            -GitHubRoot $script:gitRoot `
            -WhatIf `
            -ErrorVariable ev `
            -ErrorAction SilentlyContinue

          $ev | ForEach-Object { $errorMessages += $_.Exception.Message }
          $errorMessages | Should -BeNullOrEmpty -Because 'GitHubRoot contains a matching _Planning worktree'
        } finally {
          $global:settings = $savedSettings
        }
      } finally {
        Set-Location $savedLocation
      }
    }
  }

  Context 'checkpoint roster logging' {

    It 'writes a roster entry that names the worktree and saved archive' {
      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        $savedSettings = $global:settings
        try {
          $global:settings = $null

          $convDir = Join-Path $script:planningWt 'SprintWorkSessionConversations'
          $memRoot = Join-Path $script:planningWt 'SprintWorkSessionMemorys'
          $rosterDir = Join-Path $script:planningWt 'SprintWorkSessionRoster'
          Remove-Item -LiteralPath $convDir, $memRoot, $rosterDir -Recurse -Force -ErrorAction SilentlyContinue

          Save-SprintWorkSession `
            -SprintN $script:sprintNumber `
            -PlanningRoot $script:planningWt `
            -ClaudeProjectsRoot $script:claudeProjectsRoot `
            -GitHubRoot $script:gitRoot `
            -Confirm:$false

          $rosterPath = Join-Path $rosterDir "SprintWorkSessionRoster-$($script:sprintNumber).jsonl"
          Test-Path -LiteralPath $rosterPath | Should -BeTrue

          $latestEntry = Get-Content -LiteralPath $rosterPath | Select-Object -Last 1 | ConvertFrom-Json
          $latestEntry.WorktreeName | Should -Be (Split-Path -Path $script:atapWt -Leaf)
          $latestEntry.Agent | Should -Be 'ClaudeCode'
          $latestEntry.ConversationArchiveCreated | Should -BeTrue
          $latestEntry.MemorySnapshotCreated | Should -BeTrue
          $latestEntry.MemoryFileCount | Should -Be 1
          $latestEntry.ConversationArchivePath | Should -Match 'SprintWorkSession-0007-Conversation-100-sprint-0007-work-items-'
        } finally {
          $global:settings = $savedSettings
        }
      } finally {
        Set-Location $savedLocation
      }
    }
  }

  Context 'Task 9.32 — -Agent parameter surface' {

    It 'declares an -Agent parameter with the four supported values' {
      $cmd = Get-Command -Name 'Save-SprintWorkSession' -CommandType Function
      $cmd.Parameters.ContainsKey('Agent') | Should -BeTrue
      $validateSet = $cmd.Parameters['Agent'].Attributes |
        Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
      $validateSet.ValidValues | Should -Be @('ClaudeCode', 'Antigravity', 'Codex', 'Copilot')
    }

    It 'declares -ConversationId, -SessionId, -ConversationFile, -AntigravityRoot, -CodexRoot' {
      $cmd = Get-Command -Name 'Save-SprintWorkSession' -CommandType Function
      foreach ($p in 'ConversationId', 'SessionId', 'ConversationFile', 'AntigravityRoot', 'CodexRoot') {
        $cmd.Parameters.ContainsKey($p) | Should -BeTrue -Because "the function must expose -$p"
      }
    }
  }

  Context 'Task 9.32 — Antigravity path' {

    It 'archives transcript_full.jsonl, copies brain artifacts (excluding .system_generated), records the conversation DB' {
      $agRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ssws-ag-' + [guid]::NewGuid().ToString('N'))
      $convId = [guid]::NewGuid().ToString()
      $brainFolder = Join-Path $agRoot "brain\$convId"
      $logsDir = Join-Path $brainFolder '.system_generated\logs'
      New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $logsDir 'transcript_full.jsonl') -Value '{"role":"user"}' -Encoding UTF8
      Set-Content -LiteralPath (Join-Path $brainFolder 'note.md') -Value '# memory note' -Encoding UTF8
      $artifacts = Join-Path $brainFolder 'artifacts'
      New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $artifacts 'plan.txt') -Value 'plan' -Encoding UTF8
      $convDbDir = Join-Path $agRoot 'conversations'
      New-Item -ItemType Directory -Path $convDbDir -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $convDbDir "$convId.db") -Value 'sqlite' -Encoding UTF8

      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        $savedSettings = $global:settings
        try {
          $global:settings = $null
          Save-SprintWorkSession `
            -Agent Antigravity `
            -ConversationId $convId `
            -AntigravityRoot $agRoot `
            -SprintN $script:sprintNumber `
            -PlanningRoot $script:planningWt `
            -GitHubRoot $script:gitRoot `
            -Confirm:$false

          $rosterPath = Join-Path $script:planningWt "SprintWorkSessionRoster\SprintWorkSessionRoster-$($script:sprintNumber).jsonl"
          $entry = Get-Content -LiteralPath $rosterPath | Select-Object -Last 1 | ConvertFrom-Json
          $entry.Agent | Should -Be 'Antigravity'
          $entry.AgentSessionKey | Should -Be $convId
          $entry.ConversationArchiveCreated | Should -BeTrue
          $entry.MemorySnapshotCreated | Should -BeTrue
          $entry.MemoryFileCount | Should -BeGreaterThan 0
          $entry.ConversationDbPath | Should -Match ([regex]::Escape("$convId.db"))

          # Memory snapshot must contain the brain artifacts but NOT .system_generated.
          Test-Path -LiteralPath (Join-Path $entry.MemorySnapshotPath 'note.md') | Should -BeTrue
          Test-Path -LiteralPath (Join-Path $entry.MemorySnapshotPath '.system_generated') | Should -BeFalse
        } finally {
          $global:settings = $savedSettings
        }
      } finally {
        Set-Location $savedLocation
        Remove-Item -Recurse -Force $agRoot -ErrorAction SilentlyContinue
      }
    }

    It 'falls back to transcript.jsonl when transcript_full.jsonl is absent' {
      $agRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ssws-ag-' + [guid]::NewGuid().ToString('N'))
      $convId = [guid]::NewGuid().ToString()
      $logsDir = Join-Path $agRoot "brain\$convId\.system_generated\logs"
      New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $logsDir 'transcript.jsonl') -Value '{"role":"user"}' -Encoding UTF8

      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        $savedSettings = $global:settings
        try {
          $global:settings = $null
          Save-SprintWorkSession `
            -Agent Antigravity -ConversationId $convId -AntigravityRoot $agRoot `
            -SprintN $script:sprintNumber -PlanningRoot $script:planningWt -GitHubRoot $script:gitRoot `
            -Confirm:$false

          $rosterPath = Join-Path $script:planningWt "SprintWorkSessionRoster\SprintWorkSessionRoster-$($script:sprintNumber).jsonl"
          $entry = Get-Content -LiteralPath $rosterPath | Select-Object -Last 1 | ConvertFrom-Json
          $entry.Agent | Should -Be 'Antigravity'
          $entry.ConversationJsonlPath | Should -Match 'transcript\.jsonl$'
          $entry.ConversationArchiveCreated | Should -BeTrue
        } finally {
          $global:settings = $savedSettings
        }
      } finally {
        Set-Location $savedLocation
        Remove-Item -Recurse -Force $agRoot -ErrorAction SilentlyContinue
      }
    }

    It 'auto-detects the newest brain folder when -ConversationId is omitted' {
      $agRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ssws-ag-' + [guid]::NewGuid().ToString('N'))
      $convId = [guid]::NewGuid().ToString()
      $logsDir = Join-Path $agRoot "brain\$convId\.system_generated\logs"
      New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $logsDir 'transcript_full.jsonl') -Value '{"role":"user"}' -Encoding UTF8

      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        $savedSettings = $global:settings
        try {
          $global:settings = $null
          Save-SprintWorkSession `
            -Agent Antigravity -AntigravityRoot $agRoot `
            -SprintN $script:sprintNumber -PlanningRoot $script:planningWt -GitHubRoot $script:gitRoot `
            -Confirm:$false

          $rosterPath = Join-Path $script:planningWt "SprintWorkSessionRoster\SprintWorkSessionRoster-$($script:sprintNumber).jsonl"
          $entry = Get-Content -LiteralPath $rosterPath | Select-Object -Last 1 | ConvertFrom-Json
          $entry.AgentSessionKey | Should -Be $convId
        } finally {
          $global:settings = $savedSettings
        }
      } finally {
        Set-Location $savedLocation
        Remove-Item -Recurse -Force $agRoot -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'Task 9.32 — Codex path' {

    It 'archives the rollout JSONL for an explicit -SessionId and skips memory' {
      $codexRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ssws-codex-' + [guid]::NewGuid().ToString('N'))
      $sessionId = [guid]::NewGuid().ToString()
      $dated = Join-Path $codexRoot 'sessions\2026\06\16'
      New-Item -ItemType Directory -Path $dated -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $dated "rollout-2026-06-16T10-00-00-$sessionId.jsonl") -Value '{"role":"user"}' -Encoding UTF8

      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        $savedSettings = $global:settings
        try {
          $global:settings = $null
          Save-SprintWorkSession `
            -Agent Codex -SessionId $sessionId -CodexRoot $codexRoot `
            -SprintN $script:sprintNumber -PlanningRoot $script:planningWt -GitHubRoot $script:gitRoot `
            -Confirm:$false

          $rosterPath = Join-Path $script:planningWt "SprintWorkSessionRoster\SprintWorkSessionRoster-$($script:sprintNumber).jsonl"
          $entry = Get-Content -LiteralPath $rosterPath | Select-Object -Last 1 | ConvertFrom-Json
          $entry.Agent | Should -Be 'Codex'
          $entry.AgentSessionKey | Should -Be $sessionId
          $entry.ConversationArchiveCreated | Should -BeTrue
          $entry.MemorySnapshotCreated | Should -BeFalse
          $entry.MemorySkipReason | Should -Match 'no on-disk memory'
        } finally {
          $global:settings = $savedSettings
        }
      } finally {
        Set-Location $savedLocation
        Remove-Item -Recurse -Force $codexRoot -ErrorAction SilentlyContinue
      }
    }

    It 'auto-detects the newest rollout and recovers the session id from the filename' {
      $codexRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ssws-codex-' + [guid]::NewGuid().ToString('N'))
      $sessionId = [guid]::NewGuid().ToString()
      $dated = Join-Path $codexRoot 'sessions\2026\06\16'
      New-Item -ItemType Directory -Path $dated -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $dated "rollout-2026-06-16T10-00-00-$sessionId.jsonl") -Value '{"role":"user"}' -Encoding UTF8

      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        $savedSettings = $global:settings
        try {
          $global:settings = $null
          Save-SprintWorkSession `
            -Agent Codex -CodexRoot $codexRoot `
            -SprintN $script:sprintNumber -PlanningRoot $script:planningWt -GitHubRoot $script:gitRoot `
            -Confirm:$false

          $rosterPath = Join-Path $script:planningWt "SprintWorkSessionRoster\SprintWorkSessionRoster-$($script:sprintNumber).jsonl"
          $entry = Get-Content -LiteralPath $rosterPath | Select-Object -Last 1 | ConvertFrom-Json
          $entry.AgentSessionKey | Should -Be $sessionId
        } finally {
          $global:settings = $savedSettings
        }
      } finally {
        Set-Location $savedLocation
        Remove-Item -Recurse -Force $codexRoot -ErrorAction SilentlyContinue
      }
    }

    It 'falls back to archived_sessions when no live rollout matches the session id' {
      $codexRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ssws-codex-' + [guid]::NewGuid().ToString('N'))
      $sessionId = [guid]::NewGuid().ToString()
      $archived = Join-Path $codexRoot 'archived_sessions'
      New-Item -ItemType Directory -Path $archived -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $archived "rollout-2026-06-15T09-00-00-$sessionId.jsonl") -Value '{"role":"user"}' -Encoding UTF8

      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        $savedSettings = $global:settings
        try {
          $global:settings = $null
          Save-SprintWorkSession `
            -Agent Codex -SessionId $sessionId -CodexRoot $codexRoot `
            -SprintN $script:sprintNumber -PlanningRoot $script:planningWt -GitHubRoot $script:gitRoot `
            -Confirm:$false

          $rosterPath = Join-Path $script:planningWt "SprintWorkSessionRoster\SprintWorkSessionRoster-$($script:sprintNumber).jsonl"
          $entry = Get-Content -LiteralPath $rosterPath | Select-Object -Last 1 | ConvertFrom-Json
          $entry.ConversationJsonlPath | Should -Match 'archived_sessions'
          $entry.ConversationArchiveCreated | Should -BeTrue
        } finally {
          $global:settings = $savedSettings
        }
      } finally {
        Set-Location $savedLocation
        Remove-Item -Recurse -Force $codexRoot -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'Task 9.32 — Copilot path delegation' {

    It 'throws an actionable error when -ConversationFile is omitted' {
      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        { Save-SprintWorkSession `
            -Agent Copilot `
            -SprintN $script:sprintNumber -PlanningRoot $script:planningWt -GitHubRoot $script:gitRoot `
            -Confirm:$false } | Should -Throw -ExpectedMessage '*requires -ConversationFile*'
      } finally {
        Set-Location $savedLocation
      }
    }

    It 'delegates to Save-CopilotCheckpoint when -ConversationFile is supplied' {
      $script:ccCalled = $false
      $script:ccFile = $null
      function global:Save-CopilotCheckpoint {
        param(
          [string]$ConversationFile,
          [string]$SprintN,
          [string]$PlanningRoot,
          [string]$GitHubRoot,
          [switch]$AllowMainFallback
        )
        $script:ccCalled = $true
        $script:ccFile = $ConversationFile
      }
      $tmpConv = Join-Path ([System.IO.Path]::GetTempPath()) ('ssws-cop-' + [guid]::NewGuid().ToString('N') + '.md')
      Set-Content -LiteralPath $tmpConv -Value '# conversation' -Encoding UTF8

      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        Save-SprintWorkSession `
          -Agent Copilot -ConversationFile $tmpConv `
          -SprintN $script:sprintNumber -PlanningRoot $script:planningWt -GitHubRoot $script:gitRoot `
          -Confirm:$false

        $script:ccCalled | Should -BeTrue
        $script:ccFile | Should -Be $tmpConv
      } finally {
        Set-Location $savedLocation
        Remove-Item -LiteralPath $tmpConv -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath 'Function:\Save-CopilotCheckpoint') {
          Remove-Item -LiteralPath 'Function:\Save-CopilotCheckpoint' -ErrorAction SilentlyContinue
        }
      }
    }
  }
}

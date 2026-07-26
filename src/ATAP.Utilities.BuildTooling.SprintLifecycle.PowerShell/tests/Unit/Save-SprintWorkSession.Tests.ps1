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

  # Task 13.76.d: the archive contents are now asserted after `7z a`, so this stand-in must
  # model BOTH the add and the bare list. It records what each archive "contains" so `l -ba`
  # can echo a listing in 7-Zip's real bare format (date, time, attrs, size, packed, name).
  # $global:MockSevenZipContents lets a test force an empty or wrong-payload archive.
  $global:MockSevenZipContents = @{}

  function global:7z {
    param(
      [Parameter(ValueFromRemainingArguments = $true)]
      [string[]]$Args
    )

    $action = $Args[0]
    $rest = @($Args | Select-Object -Skip 1 | Where-Object { $_ -notlike '-*' })

    switch ($action) {
      'a' {
        $archivePath = $rest[0]
        $sourcePath = $rest[1]
        New-Item -ItemType Directory -Path (Split-Path -Path $archivePath -Parent) -Force | Out-Null
        Set-Content -LiteralPath $archivePath -Value "mock archive for $sourcePath" -Encoding UTF8
        if (-not $global:MockSevenZipContents.ContainsKey($archivePath)) {
          $global:MockSevenZipContents[$archivePath] = @([IO.Path]::GetFileName($sourcePath))
        }
      }
      'l' {
        $archivePath = $rest[0]
        # A test may force the listing for every archive (Task 13.76.d assertion cases);
        # otherwise echo whatever `a` recorded for this archive.
        $names = if ($null -ne $global:MockSevenZipForcedEntries) {
          @($global:MockSevenZipForcedEntries)
        }
        elseif ($global:MockSevenZipContents.ContainsKey($archivePath)) {
          @($global:MockSevenZipContents[$archivePath])
        }
        else { @() }
        foreach ($name in $names) {
          if (-not [string]::IsNullOrWhiteSpace($name)) {
            '2026-07-25 10:08:16 ....A            9           13  ' + $name
          }
        }
      }
      default { throw "Unexpected 7z action: $action" }
    }
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
  Remove-Variable -Name MockSevenZipContents -Scope Global -ErrorAction SilentlyContinue
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

  Context 'Task 12.29 — Claude project slug directory casing' {

    It 'records and copies memory from the actual on-disk Claude project directory casing' {
      $customClaudeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ssws-case-' + [guid]::NewGuid().ToString('N'))
      $customPlanRoot   = Join-Path ([System.IO.Path]::GetTempPath()) ('ssws-plan-' + [guid]::NewGuid().ToString('N'))

      $expectedLowerSlug = ($script:atapWt.Substring(0, 1).ToLower() + $script:atapWt.Substring(1)) `
        -replace ':', '-' -replace '\\', '-' -replace '_', '-' -replace '\.', '-' -replace '^-', ''
      $actualSlug = $expectedLowerSlug.Substring(0, 1).ToUpper() + $expectedLowerSlug.Substring(1)

      $actualSessionDir = Join-Path $customClaudeRoot $actualSlug
      $actualMemoryDir = Join-Path $actualSessionDir 'memory'
      New-Item -ItemType Directory -Path $actualMemoryDir, $customPlanRoot -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $actualSessionDir 'case-test.jsonl') `
        -Value '{"role":"user","content":"case"}' -Encoding UTF8
      Set-Content -LiteralPath (Join-Path $actualMemoryDir 'case-memory.md') `
        -Value '# case memory' -Encoding UTF8

      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        $savedSettings = $global:settings
        try {
          $global:settings = $null

          Save-SprintWorkSession `
            -SprintN $script:sprintNumber `
            -PlanningRoot $customPlanRoot `
            -ClaudeProjectsRoot $customClaudeRoot `
            -GitHubRoot $script:gitRoot `
            -Confirm:$false

          $rosterPath = Join-Path $customPlanRoot "SprintWorkSessionRoster\SprintWorkSessionRoster-$($script:sprintNumber).jsonl"
          $entry = Get-Content -LiteralPath $rosterPath | Select-Object -Last 1 | ConvertFrom-Json
          $entry.MemorySourcePath | Should -BeExactly $actualMemoryDir
          $entry.MemorySnapshotCreated | Should -BeTrue
          Test-Path -LiteralPath (Join-Path $entry.MemorySnapshotPath 'case-memory.md') | Should -BeTrue
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
          # Task 13.20.f: names now carry repo/worktree identity ahead of the branch
          # tag so two repos sharing a branch name cannot collide.
          $expectedRepoTag = (Split-Path -Path $script:atapWt -Leaf) -replace '[^A-Za-z0-9\-]', '-'
          $latestEntry.ConversationArchivePath | Should -Match "SprintWorkSession-0007-Conversation-$([regex]::Escape($expectedRepoTag))-100-sprint-0007-work-items-"
        } finally {
          $global:settings = $savedSettings
        }
      } finally {
        Set-Location $savedLocation
      }
    }
  }

  Context 'Task 13.76.d — archive content assertion' {

    BeforeAll {
      # Runs one checkpoint with the mock 7z forced to report $ArchiveEntries for whatever
      # archive it creates, and returns the terminating error (or $null on success).
      function script:Invoke-CheckpointWithArchiveEntries {
        param([AllowEmptyCollection()][string[]] $ArchiveEntries)

        $savedLocation = Get-Location
        Set-Location $script:atapWt
        try {
          $savedSettings = $global:settings
          $global:settings = $null
          $convDir = Join-Path $script:planningWt 'SprintWorkSessionConversations'
          $rosterDir = Join-Path $script:planningWt 'SprintWorkSessionRoster'
          Remove-Item -LiteralPath $convDir, $rosterDir -Recurse -Force -ErrorAction SilentlyContinue

          $global:MockSevenZipContents = @{}
          $global:MockSevenZipForcedEntries = $ArchiveEntries
          try {
            Save-SprintWorkSession `
              -SprintN $script:sprintNumber `
              -PlanningRoot $script:planningWt `
              -ClaudeProjectsRoot $script:claudeProjectsRoot `
              -GitHubRoot $script:gitRoot `
              -Confirm:$false
            return $null
          }
          catch {
            return $_
          }
          finally {
            Remove-Variable -Name MockSevenZipForcedEntries -Scope Global -ErrorAction SilentlyContinue
            $global:settings = $savedSettings
          }
        } finally {
          Set-Location $savedLocation
        }
      }
    }

    It 'fails loudly when 7z produced an archive with no entries' {
      # The original defect: Test-Path alone reported ConversationArchiveCreated = $true
      # for an archive that held nothing at all.
      $err = script:Invoke-CheckpointWithArchiveEntries -ArchiveEntries @()

      $err | Should -Not -BeNullOrEmpty
      $err.Exception.Message | Should -Match 'contains no files'
    }

    It 'fails loudly when the archive exists but omits the rollout JSONL' {
      # The close variant: a non-empty archive that captured the wrong payload still
      # means the conversation was not saved.
      $err = script:Invoke-CheckpointWithArchiveEntries -ArchiveEntries @('some-other-file.txt')

      $err | Should -Not -BeNullOrEmpty
      $err.Exception.Message | Should -Match "rollout file 'fake-session\.jsonl' is absent"
    }

    It 'succeeds and records the archive when the rollout JSONL is present' {
      $err = script:Invoke-CheckpointWithArchiveEntries -ArchiveEntries @('fake-session.jsonl')
      $err | Should -BeNullOrEmpty

      $rosterPath = Join-Path $script:planningWt "SprintWorkSessionRoster\SprintWorkSessionRoster-$($script:sprintNumber).jsonl"
      $latestEntry = Get-Content -LiteralPath $rosterPath | Select-Object -Last 1 | ConvertFrom-Json
      $latestEntry.ConversationArchiveCreated | Should -BeTrue
    }

    It 'accepts a listing whose entry name is preceded by 7-Zip metadata columns' {
      # Guards the assertion against 7-Zip's real bare-listing shape: the original
      # proposed patch counted entries with '^\s*\d+\s+\S+', which never matches a line
      # beginning with an ISO date, so every checkpoint would have thrown.
      $err = script:Invoke-CheckpointWithArchiveEntries -ArchiveEntries @('fake-session.jsonl')
      $err | Should -BeNullOrEmpty
    }

    It 'stages long transcript names under the system temporary directory before calling 7z' {
      # The durable archive name intentionally includes sprint, worktree, branch, and
      # collision data; using that same path for a staging directory exceeded 7-Zip's
      # legacy path limit and produced a 59-byte empty archive with exit code zero.
      $sourcePath = (Get-Command -Name 'Save-SprintWorkSession' -CommandType Function).ScriptBlock.File
      $source = Get-Content -LiteralPath $sourcePath -Raw

      $source | Should -Match '\[IO\.Path\]::GetTempPath\(\)'
      $source | Should -Not -Match '\$snapshotDir = Join-Path \$convDir'
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

    It 'writes a canonical roster entry through the Copilot checkpoint path' {
      $copilotFunctionPath = Join-Path $PSScriptRoot '..\..\public\Save-CopilotCheckpoint.ps1'
      . $copilotFunctionPath
      $tmpConv = Join-Path ([System.IO.Path]::GetTempPath()) ('ssws-cop-roster-' + [guid]::NewGuid().ToString('N') + '.md')
      $missingMemoryRoot = Join-Path $script:gitRoot 'copilot-memory-does-not-exist'
      Set-Content -LiteralPath $tmpConv -Value '# conversation' -Encoding UTF8

      $savedLocation = Get-Location
      Set-Location $script:atapWt
      try {
        Save-CopilotCheckpoint `
          -ConversationFile $tmpConv `
          -SprintN $script:sprintNumber -PlanningRoot $script:planningWt -GitHubRoot $script:gitRoot `
          -CopilotMemoryRoot $missingMemoryRoot -Confirm:$false

        $rosterPath = Join-Path $script:planningWt "SprintWorkSessionRoster\SprintWorkSessionRoster-$($script:sprintNumber).jsonl"
        $entry = Get-Content -LiteralPath $rosterPath | Select-Object -Last 1 | ConvertFrom-Json
        $entry.Agent | Should -Be 'Copilot'
        $entry.ConversationArchiveCreated | Should -BeTrue
        (Test-Path -LiteralPath $entry.ConversationArchivePath) | Should -BeTrue
        $entry.MemorySnapshotCreated | Should -BeFalse
        $entry.MemorySkipReason | Should -Match 'Memory directory not found'
      } finally {
        Set-Location $savedLocation
        Remove-Item -LiteralPath $tmpConv -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath 'Function:\Save-CopilotCheckpoint') {
          Remove-Item -LiteralPath 'Function:\Save-CopilotCheckpoint' -ErrorAction SilentlyContinue
        }
      }
    }
  }

  Context 'Task 13.20.f — collision-free checkpoint names across repos/worktrees' {

    BeforeAll {
      $script:checkpointNameHelperPath = Join-Path $PSScriptRoot '..\..\private\New-CheckpointNameComponents.ps1'
      if (-not (Test-Path -LiteralPath $script:checkpointNameHelperPath)) {
        throw "Helper not found: $script:checkpointNameHelperPath"
      }
      . $script:checkpointNameHelperPath
    }

    It 'New-CheckpointNameComponents produces four unique conversation and memory names for four checkpoints fired in the same second, from two different repo identities' {
      # Simulate two stable repos both on branch `main`, checkpointing twice
      # each — four calls total, no artificial delay between them, so all four
      # land in the same wall-clock second (the exact defect this task fixes).
      $calls = @(
        @{ WorktreeName = 'ATAP.Utilities';   Branch = 'main' }
        @{ WorktreeName = 'ATAP.Utilities';   Branch = 'main' }
        @{ WorktreeName = 'AceCommander';     Branch = 'main' }
        @{ WorktreeName = 'AceCommander';     Branch = 'main' }
      )

      $results = foreach ($call in $calls) {
        New-CheckpointNameComponents -SprintN '0013' -WorktreeName $call.WorktreeName -Branch $call.Branch
      }

      ($results | Measure-Object).Count | Should -Be 4

      $convNames = $results | Select-Object -ExpandProperty ConvName
      $memNames  = $results | Select-Object -ExpandProperty MemName

      ($convNames | Select-Object -Unique | Measure-Object).Count | Should -Be 4 -Because 'four checkpoints in the same second must not collide on conversation-archive name'
      ($memNames  | Select-Object -Unique | Measure-Object).Count | Should -Be 4 -Because 'four checkpoints in the same second must not collide on memory-snapshot name'

      # Repo identity must be present so the two 'ATAP.Utilities' entries differ
      # from the two 'AceCommander' entries even though both share branch 'main'.
      $convNames[0] | Should -Match 'ATAP-Utilities'
      $convNames[1] | Should -Match 'ATAP-Utilities'
      $convNames[2] | Should -Match 'AceCommander'
      $convNames[3] | Should -Match 'AceCommander'
    }

    It 'end-to-end: two Save-SprintWorkSession checkpoints from different repo worktrees on the same branch produce distinct archive and memory names' {
      # Build a second fake repo worktree, also on a branch literally named 'main',
      # sitting alongside $script:atapWt (which is on a sprint branch) — mirrors
      # the real defect of two *different* repos both on branch `main`.
      $secondRepoRoot = Join-Path $script:gitRoot 'AceCommander-stable-sim'
      New-Item -ItemType Directory -Path $secondRepoRoot -Force | Out-Null
      & git -C $secondRepoRoot init --quiet --initial-branch=main 2>$null
      & git -C $secondRepoRoot config user.email 'test@example.com'
      & git -C $secondRepoRoot config user.name 'Pester Tester'
      Set-Content -LiteralPath (Join-Path $secondRepoRoot 'README.md') -Value 'seed' -Encoding UTF8
      & git -C $secondRepoRoot add . 2>$null | Out-Null
      & git -C $secondRepoRoot commit --quiet -m 'seed' 2>$null | Out-Null

      # A minimal Claude-projects session for the second repo's slug.
      $secondSlug = ($secondRepoRoot.Substring(0, 1).ToLower() + $secondRepoRoot.Substring(1)) `
        -replace ':', '-' -replace '\\', '-' -replace '_', '-' -replace '\.', '-' -replace '^-', ''
      $secondSessionDir = Join-Path $script:claudeProjectsRoot $secondSlug
      New-Item -ItemType Directory -Path $secondSessionDir -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $secondSessionDir 'second-repo.jsonl') -Value '{"role":"user","content":"second"}' -Encoding UTF8
      $secondMemoryDir = Join-Path $secondSessionDir 'memory'
      New-Item -ItemType Directory -Path $secondMemoryDir -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $secondMemoryDir 'second-memory.md') -Value '# second memory' -Encoding UTF8

      # Also seed $script:atapWt's own branch as 'main' isn't possible (it uses a
      # sprint branch name by design for auto-detect), so instead pass -SprintN
      # explicitly for both calls and rely on the two repos' differing worktree
      # names to prove collision-freedom even when name components otherwise
      # overlap (same SprintN, same PlanningRoot).
      $convDir = Join-Path $script:planningWt 'SprintWorkSessionConversations'
      $memRoot = Join-Path $script:planningWt 'SprintWorkSessionMemorys'
      $rosterDir = Join-Path $script:planningWt 'SprintWorkSessionRoster'
      Remove-Item -LiteralPath $convDir, $memRoot, $rosterDir -Recurse -Force -ErrorAction SilentlyContinue

      $savedLocation = Get-Location
      $savedSettings = $global:settings
      try {
        $global:settings = $null

        Set-Location $script:atapWt
        Save-SprintWorkSession `
          -SprintN $script:sprintNumber `
          -PlanningRoot $script:planningWt `
          -ClaudeProjectsRoot $script:claudeProjectsRoot `
          -GitHubRoot $script:gitRoot `
          -Confirm:$false

        Set-Location $secondRepoRoot
        Save-SprintWorkSession `
          -SprintN $script:sprintNumber `
          -PlanningRoot $script:planningWt `
          -ClaudeProjectsRoot $script:claudeProjectsRoot `
          -GitHubRoot $script:gitRoot `
          -Confirm:$false

        $rosterPath = Join-Path $rosterDir "SprintWorkSessionRoster-$($script:sprintNumber).jsonl"
        $entries = Get-Content -LiteralPath $rosterPath | Select-Object -Last 2 | ForEach-Object { $_ | ConvertFrom-Json }
        ($entries | Measure-Object).Count | Should -Be 2

        $archivePaths = $entries | Select-Object -ExpandProperty ConversationArchivePath
        $memoryPaths  = $entries | Select-Object -ExpandProperty MemorySnapshotPath

        ($archivePaths | Select-Object -Unique | Measure-Object).Count | Should -Be 2 -Because 'two different repo worktrees must not collide on conversation-archive name'
        ($memoryPaths  | Select-Object -Unique | Measure-Object).Count | Should -Be 2 -Because 'two different repo worktrees must not collide on memory-snapshot name'

        # Both archives must actually exist on disk (no overwrite occurred).
        foreach ($p in $archivePaths) { Test-Path -LiteralPath $p | Should -BeTrue }
      } finally {
        $global:settings = $savedSettings
        Set-Location $savedLocation
        Remove-Item -Recurse -Force $secondRepoRoot, $secondSessionDir -ErrorAction SilentlyContinue
      }
    }
  }
}

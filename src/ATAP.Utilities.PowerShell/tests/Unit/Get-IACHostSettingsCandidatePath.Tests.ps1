<#
  Regression suite for SC-0252.

  Get-HostSettings used to hard-code 'ATAP.IAC-wt-9-Sprint-0007-work-items' as its only
  sprint-shaped candidate base path. When that worktree was deleted at the end of Sprint 0007,
  resolution silently fell through to the stable ATAP.IAC checkout, and every HostSettings edit made
  in a sprint worktree stopped having any effect. It went unnoticed for four sprints because every
  existing Get-HostSettings test passed -IACBasePath explicitly, so the DEFAULT candidate chain --
  the only one that ever runs in production -- was never exercised.

  These tests exercise the default chain against a fixture tree.
#>

BeforeAll {
  $functionFile = Join-Path $PSScriptRoot '..\..\private\Get-IACHostSettingsCandidatePath.ps1'
  if (-not (Test-Path -LiteralPath $functionFile -PathType Leaf)) {
    throw "Function file not found: $functionFile"
  }
  . $functionFile

  function New-FixtureRoot {
    param([string[]]$Directory)
    $root = Join-Path $PSScriptRoot ('_tmp_IACCandidates_' + [guid]::NewGuid().ToString('N'))
    foreach ($d in $Directory) { New-Item -Path (Join-Path $root $d) -ItemType Directory -Force | Out-Null }
    $root
  }
}

Describe 'Get-IACHostSettingsCandidatePath' -Tag 'Unit' {

  BeforeEach {
    # The helper reads these directly, so make sure a real machine value cannot leak into a test.
    $script:savedProcessEnv = [System.Environment]::GetEnvironmentVariable('ATAP_IAC_BASE_PATH', 'Process')
    [System.Environment]::SetEnvironmentVariable('ATAP_IAC_BASE_PATH', $null, 'Process')
  }

  AfterEach {
    [System.Environment]::SetEnvironmentVariable('ATAP_IAC_BASE_PATH', $script:savedProcessEnv, 'Process')
    Get-ChildItem $PSScriptRoot -Directory -Filter '_tmp_IACCandidates_*' -ErrorAction SilentlyContinue |
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  }

  Context 'Sprint worktree discovery (the SC-0252 regression)' {

    It 'puts the current sprint worktree ahead of the stable checkout' {
      $root = New-FixtureRoot -Directory @('ATAP.IAC', 'ATAP.IAC-wt-15-Sprint-0012-work-items')
      $result = @(Get-IACHostSettingsCandidatePath -SearchRoot $root)

      $result[0] | Should -Be (Join-Path $root 'ATAP.IAC-wt-15-Sprint-0012-work-items')
      $result[1] | Should -Be (Join-Path $root 'ATAP.IAC')
    }

    It 'discovers the sprint worktree by pattern, so it survives the sprint that created it ending' {
      # The exact failure: a literal naming Sprint 0007's worktree. A pattern match does not care
      # which sprint is current.
      $root = New-FixtureRoot -Directory @('ATAP.IAC', 'ATAP.IAC-wt-42-Sprint-0099-some-slug')
      $result = @(Get-IACHostSettingsCandidatePath -SearchRoot $root)
      $result[0] | Should -Be (Join-Path $root 'ATAP.IAC-wt-42-Sprint-0099-some-slug')
    }

    It 'picks the highest sprint number, comparing as integers rather than lexically' {
      # 'wt-9-Sprint-0007' sorts ABOVE 'wt-15-Sprint-0012' as a string. It must not win.
      $root = New-FixtureRoot -Directory @(
        'ATAP.IAC'
        'ATAP.IAC-wt-9-Sprint-0007-work-items'
        'ATAP.IAC-wt-15-Sprint-0012-work-items'
      )
      $result = @(Get-IACHostSettingsCandidatePath -SearchRoot $root)
      $result[0] | Should -Be (Join-Path $root 'ATAP.IAC-wt-15-Sprint-0012-work-items')
    }

    It 'breaks a same-sprint tie on the worktree number, also as an integer' {
      $root = New-FixtureRoot -Directory @(
        'ATAP.IAC-wt-7-Sprint-0012-work-items'
        'ATAP.IAC-wt-120-Sprint-0012-work-items'
      )
      $result = @(Get-IACHostSettingsCandidatePath -SearchRoot $root)
      $result[0] | Should -Be (Join-Path $root 'ATAP.IAC-wt-120-Sprint-0012-work-items')
    }

    It 'offers only the stable checkout when no sprint worktree exists' {
      $root = New-FixtureRoot -Directory @('ATAP.IAC')
      $result = @(Get-IACHostSettingsCandidatePath -SearchRoot $root)
      $result | Should -Be @((Join-Path $root 'ATAP.IAC'))
    }

    It 'ignores directories that only look like a worktree' {
      $root = New-FixtureRoot -Directory @(
        'ATAP.IAC'
        'ATAP.IAC-backup'
        'ATAP.Utilities-wt-120-Sprint-0012-work-items'   # a different repo's worktree
        'ATAP.IAC-wt-Sprint-0012'                        # no worktree number
      )
      $result = @(Get-IACHostSettingsCandidatePath -SearchRoot $root)
      $result | Should -Be @((Join-Path $root 'ATAP.IAC'))
    }
  }

  Context 'Precedence' {

    It 'places an explicit -IACBasePath ahead of everything discovered' {
      $root = New-FixtureRoot -Directory @('ATAP.IAC', 'ATAP.IAC-wt-15-Sprint-0012-work-items')
      $result = @(Get-IACHostSettingsCandidatePath -IACBasePath 'D:\explicit\ATAP.IAC' -SearchRoot $root)
      $result[0] | Should -Be 'D:\explicit\ATAP.IAC'
    }

    It 'honours $env:ATAP_IAC_BASE_PATH ahead of the discovered sprint worktree' {
      # An operator naming a path outranks anything the function found on its own.
      [System.Environment]::SetEnvironmentVariable('ATAP_IAC_BASE_PATH', 'D:\from-env\ATAP.IAC', 'Process')
      $root = New-FixtureRoot -Directory @('ATAP.IAC', 'ATAP.IAC-wt-15-Sprint-0012-work-items')
      $result = @(Get-IACHostSettingsCandidatePath -SearchRoot $root)
      $result[0] | Should -Be 'D:\from-env\ATAP.IAC'
      $result[1] | Should -Be (Join-Path $root 'ATAP.IAC-wt-15-Sprint-0012-work-items')
    }

    It 'appends the installed-module resource path last' {
      $root = New-FixtureRoot -Directory @('ATAP.IAC')
      $result = @(Get-IACHostSettingsCandidatePath -SearchRoot $root -ProgramFilesResourcePath 'C:\PF\Resources')
      $result[-1] | Should -Be 'C:\PF\Resources'
    }

    It 'searches every root, sprint worktrees before any stable checkout' {
      $rootA = New-FixtureRoot -Directory @('ATAP.IAC')
      $rootB = New-FixtureRoot -Directory @('ATAP.IAC', 'ATAP.IAC-wt-15-Sprint-0012-work-items')
      $result = @(Get-IACHostSettingsCandidatePath -SearchRoot @($rootA, $rootB))

      $result[0] | Should -Be (Join-Path $rootB 'ATAP.IAC-wt-15-Sprint-0012-work-items')
      $result[1] | Should -Be (Join-Path $rootA 'ATAP.IAC')
      $result[2] | Should -Be (Join-Path $rootB 'ATAP.IAC')
    }
  }

  Context 'Hygiene' {

    It 'collapses search roots that resolve to the same directory' {
      # MyDocuments is redirected into the Dropbox tree on this workstation, so the two roots
      # Get-HostSettings passes are frequently the same folder.
      $root = New-FixtureRoot -Directory @('ATAP.IAC')
      $result = @(Get-IACHostSettingsCandidatePath -SearchRoot @($root, "$root\", $root))
      $result | Should -Be @((Join-Path $root 'ATAP.IAC'))
    }

    It 'emits no duplicates and no empty entries' {
      $root = New-FixtureRoot -Directory @('ATAP.IAC')
      $result = @(Get-IACHostSettingsCandidatePath -IACBasePath '' -SearchRoot @($root, '', $null) -ProgramFilesResourcePath '')
      $result | Should -Not -Contain ''
      ($result | Select-Object -Unique).Count | Should -Be $result.Count
    }

    It 'returns an empty list rather than throwing when nothing is supplied' {
      $result = @(Get-IACHostSettingsCandidatePath)
      $result.Count | Should -Be 0
    }

    It 'tolerates a search root that does not exist' {
      $result = @(Get-IACHostSettingsCandidatePath -SearchRoot 'D:\definitely\not\here')
      $result | Should -Be @('D:\definitely\not\here\ATAP.IAC')
    }
  }
}

Describe 'Get-HostSettings default candidate chain' -Tag 'Unit' {

  # Guards the integration point, not just the helper: Get-HostSettings must actually CALL the
  # discovery helper rather than reintroduce a literal.

  It 'contains no hard-coded sprint worktree literal' {
    $source = Get-Content (Join-Path $PSScriptRoot '..\..\public\Get-HostSettings.ps1') -Raw
    # A literal sprint worktree path in the candidate chain is the SC-0252 bug by definition.
    $source | Should -Not -Match "Add-CandidatePath[^\r\n]*ATAP\.IAC-wt-\d+-[Ss]print"
  }

  It 'delegates candidate ordering to Get-IACHostSettingsCandidatePath' {
    $source = Get-Content (Join-Path $PSScriptRoot '..\..\public\Get-HostSettings.ps1') -Raw
    $source | Should -Match 'Get-IACHostSettingsCandidatePath'
  }
}

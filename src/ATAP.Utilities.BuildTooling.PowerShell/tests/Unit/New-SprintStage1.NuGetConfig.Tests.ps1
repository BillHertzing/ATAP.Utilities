#Requires -Version 7.0

# Verifies the NuGet.config that New-SprintStage1 emits into the SharedVSCode
# sprint worktree. Acceptance for A09: only permanent feed names
# (nuget-experimental, nuget-development, nuget-integration, nuget-qa,
# nuget-production, plus nuget.org; D-2); no sprint-scoped keys; full AceCommander-stable
# topology (packageSources, packageSourceCredentials, packageRestore,
# disabledPackageSources, packageSourceMapping, auditSources).

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  # K04: track every external command this suite's stubs receive. Per Stream K,
  # dot-sourcing New-SprintStage1.ps1 must trigger nothing — only an explicit
  # call to New-SprintStage1 may. The list is created before the dot-source so
  # any load-time side effect would be recorded.
  $global:stage1ExternalCalls = [System.Collections.Generic.List[string]]::new()

  function global:Assert-GitAvailable {
    $global:stage1ExternalCalls.Add('Assert-GitAvailable') | Out-Null
  }

  function global:gh {
    $global:stage1ExternalCalls.Add('gh') | Out-Null
    return 'https://github.com/owner/repo/issues/999'
  }
  $global:LASTEXITCODE = 0

  function global:git {
    $global:stage1ExternalCalls.Add('git') | Out-Null
    $global:LASTEXITCODE = 0
    return ''
  }

  function global:Set-WorktreeJunctions {
    $global:stage1ExternalCalls.Add('Set-WorktreeJunctions') | Out-Null
    [PSCustomObject]@{
      Success           = $true
      JunctionsCreated  = 3
      Errors            = @()
    }
  }

  function global:Initialize-DownstreamSprintFromSharedVSCode {
    $global:stage1ExternalCalls.Add('Initialize-DownstreamSprintFromSharedVSCode') | Out-Null
  }

  function global:Initialize-SprintAIAdapters {
    $global:stage1ExternalCalls.Add('Initialize-SprintAIAdapters') | Out-Null
  }

  function global:Get-SprintHistoryReconstruction {
    param([string]$PlanningRoot)
    [PSCustomObject]@{
      LastCompletedSprintNumber = 6
      Warnings                  = @()
    }
  }

  . "$PSScriptRoot\..\..\public\Convert-TasksMdToSprintBoard.ps1"

  # Dot-source the function definition. This defines New-SprintStage1 and must
  # not execute any Stage 1 work.
  . "$PSScriptRoot\..\..\public\New-SprintStage1.ps1"

  # K04: freeze the set of external calls observed up to and including the
  # dot-source. The 'Load contract' context below asserts this stayed empty.
  $script:callsObservedAtLoad = @($global:stage1ExternalCalls)
}

Describe 'New-SprintStage1 NuGet.config generation (A09)' -Tag 'Unit', 'PromotedModuleHostSensitive' {

  Context 'Load contract (K04)' {
    It 'dot-sourcing New-SprintStage1.ps1 defines the function without triggering Stage 1 actions' {
      Get-Command New-SprintStage1 -CommandType Function -ErrorAction SilentlyContinue |
        Should -Not -BeNullOrEmpty
      $script:callsObservedAtLoad | Should -BeNullOrEmpty -Because (
        'loading the function file must only define the function. ' +
        "Commands observed during dot-source: $($script:callsObservedAtLoad -join ', ')"
      )
    }
  }

  BeforeEach {
    $script:tempGitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "stage1_nuget_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempGitRoot -Force | Out-Null

    # Worktrees that the function would normally create via `git worktree add`.
    # Pre-create them so Set-Content on the NuGet.config inside the SharedVSCode
    # worktree succeeds without a real git invocation.
    $sharedWorktreePath = Join-Path $script:tempGitRoot 'SharedVSCode-wt-999-Sprint-0007-work-items'
    New-Item -ItemType Directory -Path $sharedWorktreePath -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:tempGitRoot '_Planning-wt-999-Sprint-0007-work-items') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $sharedWorktreePath 'NuGet.config.template') -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
    <add key="nuget-experimental" value="${ProGetBaseUrl}/nuget/nuget-experimental/v3/index.json" allowInsecureConnections="true" />
    <add key="nuget-development" value="${ProGetBaseUrl}/nuget/nuget-development/v3/index.json" allowInsecureConnections="true" />
    <add key="nuget-integration" value="${ProGetBaseUrl}/nuget/nuget-integration/v3/index.json" allowInsecureConnections="true" />
    <add key="nuget-qa" value="${ProGetBaseUrl}/nuget/nuget-qa/v3/index.json" allowInsecureConnections="true" />
    <add key="nuget-production" value="${ProGetBaseUrl}/nuget/nuget-production/v3/index.json" allowInsecureConnections="true" />
  </packageSources>
  <packageRestore>
    <add key="enabled" value="True" />
    <add key="automatic" value="True" />
  </packageRestore>
  <disabledPackageSources>
    <clear />
  </disabledPackageSources>
  <packageSourceMapping>
    <packageSource key="nuget.org"><package pattern="*" /></packageSource>
    <packageSource key="nuget-experimental"><package pattern="*" /></packageSource>
    <packageSource key="nuget-development"><package pattern="*" /></packageSource>
    <packageSource key="nuget-integration"><package pattern="*" /></packageSource>
    <packageSource key="nuget-qa"><package pattern="*" /></packageSource>
    <packageSource key="nuget-production"><package pattern="*" /></packageSource>
  </packageSourceMapping>
  <auditSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </auditSources>
</configuration>
'@

    $priorTasksPath = Join-Path $script:tempGitRoot '_Planning-wt-999-Sprint-0007-work-items' 'TASKS.md'
    Set-Content -LiteralPath $priorTasksPath -Encoding UTF8 -Value @(
      '# Current Sprint: Sprint 6 - Prior sprint'
      ''
      'Source: unit test'
      'Last updated: 2026-06-01'
      ''
      '## Goal'
      ''
      'Prior sprint goal.'
      ''
      '## Stream A - Prior work'
      ''
      '- [ ] **Task 6.1** [ATAP.Utilities] - Prior task that must not carry forward'
    )

    $script:nugetConfigPath = Join-Path $script:tempGitRoot 'SharedVSCode-wt-999-Sprint-0007-work-items' 'NuGet.config'
  }

  AfterEach {
    Remove-Item -LiteralPath $script:tempGitRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  Context 'Default ProGetBaseUrl (http://localhost:50000)' {
    BeforeEach {
      New-SprintStage1 -GitRoot $script:tempGitRoot -Owner 'owner' -SprintNumber '0007' -Confirm:$false | Out-Null
      $script:content = Get-Content -LiteralPath $script:nugetConfigPath -Raw
    }

    It 'Writes the NuGet.config to the SharedVSCode sprint worktree' {
      Test-Path -LiteralPath $script:nugetConfigPath | Should -BeTrue
    }

    It 'Is valid XML' {
      { [xml]$script:content } | Should -Not -Throw
    }

    It 'Does not contain sprint-scoped feed keys' {
      $script:content | Should -Not -Match 'nuget-Sprint\d{4}-experimental'
      $script:content | Should -Not -Match 'nuget-Sprint\d{4}-development'
    }

    It 'Contains every permanent ProGet feed key' {
      foreach ($key in @('nuget-experimental','nuget-development','nuget-integration','nuget-qa','nuget-production')) {
        $script:content | Should -Match ('key="{0}"' -f [regex]::Escape($key))
      }
    }

    It 'Contains nuget.org' {
      $script:content | Should -Match 'key="nuget.org"'
    }

    It 'Uses /v3/index.json paths for ProGet feeds' {
      foreach ($key in @('nuget-experimental','nuget-development','nuget-integration','nuget-qa','nuget-production')) {
        $script:content | Should -Match ('/nuget/{0}/v3/index\.json' -f [regex]::Escape($key))
      }
    }

    It 'Marks ProGet feeds with allowInsecureConnections="true"' {
      ([regex]::Matches($script:content, 'allowInsecureConnections="true"')).Count | Should -BeGreaterOrEqual 5
    }

    It 'Substitutes the default ProGetBaseUrl into feed URLs' {
      $script:content | Should -Match 'http://localhost:50000/nuget/nuget-experimental/v3/index\.json'
    }

    It 'Emits the packageSourceMapping section with all six sources mapped' {
      $script:content | Should -Match '<packageSourceMapping>'
      $script:content | Should -Match 'packageSource key="nuget.org"'
      foreach ($key in @('nuget-experimental','nuget-development','nuget-integration','nuget-qa','nuget-production')) {
        $script:content | Should -Match ('packageSource key="{0}"' -f [regex]::Escape($key))
      }
    }

    It 'Emits the packageRestore section with enabled and automatic set to True' {
      $script:content | Should -Match '<packageRestore>'
      $script:content | Should -Match 'key="enabled"\s+value="True"'
      $script:content | Should -Match 'key="automatic"\s+value="True"'
    }

    It 'Emits the auditSources section pointing at nuget.org' {
      $script:content | Should -Match '<auditSources>'
      $script:content | Should -Match 'key="nuget.org"\s+value="https://api\.nuget\.org/v3/index\.json"'
    }

    It 'Emits the disabledPackageSources section' {
      $script:content | Should -Match '<disabledPackageSources>'
    }
  }

  Context 'ShouldProcess target strings' {
    It 'uses the resolved owner instead of a hardcoded owner in the WhatIf target expressions' {
      $source = Get-Content -LiteralPath "$PSScriptRoot\..\..\public\New-SprintStage1.ps1" -Raw

      $source | Should -Match '\$PSCmdlet\.ShouldProcess\("\$Owner/SharedVSCode"'
      $source | Should -Match '\$PSCmdlet\.ShouldProcess\("\$Owner/_Planning"'
      $source | Should -Not -Match "ShouldProcess\('whertzing/SharedVSCode'"
      $source | Should -Not -Match "ShouldProcess\('whertzing/_Planning'"
    }
  }

  Context 'Custom ProGetBaseUrl' {
    It 'Substitutes a non-default ProGetBaseUrl into every ProGet feed URL' {
      New-SprintStage1 `
        -GitRoot $script:tempGitRoot `
        -Owner 'owner' `
        -SprintNumber '0007' `
        -ProGetBaseUrl 'http://proget.internal:51000' `
        -Confirm:$false | Out-Null

      $content = Get-Content -LiteralPath $script:nugetConfigPath -Raw
      foreach ($key in @('nuget-experimental','nuget-development','nuget-integration','nuget-qa','nuget-production')) {
        $content | Should -Match ('http://proget\.internal:51000/nuget/{0}/v3/index\.json' -f [regex]::Escape($key))
      }
      $content | Should -Not -Match 'http://localhost:50000'
    }
  }
}

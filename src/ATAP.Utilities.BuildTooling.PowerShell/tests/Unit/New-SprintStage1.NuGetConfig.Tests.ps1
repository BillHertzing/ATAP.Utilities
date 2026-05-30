#Requires -Version 7.0

# Verifies the NuGet.config that New-SprintStage1 emits into the SharedVSCode
# sprint worktree. Acceptance for A09: only permanent feed names
# (nuget-experimental, nuget-development, nuget-integration, nuget-qa,
# nuget-stable, plus nuget.org); no sprint-scoped keys; full AceCommander-stable
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

  # Dot-source the function definition. This defines New-SprintStage1 and must
  # not execute any Stage 1 work.
  . "$PSScriptRoot\..\..\public\New-SprintStage1.ps1"

  # K04: freeze the set of external calls observed up to and including the
  # dot-source. The 'Load contract' context below asserts this stayed empty.
  $script:callsObservedAtLoad = @($global:stage1ExternalCalls)
}

Describe 'New-SprintStage1 NuGet.config generation (A09)' -Tag 'Unit' {

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
    New-Item -ItemType Directory -Path (Join-Path $script:tempGitRoot 'SharedVSCode-wt-999-Sprint-0007-work-items') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:tempGitRoot '_Planning-wt-999-Sprint-0007-work-items') -Force | Out-Null

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
      foreach ($key in @('nuget-experimental','nuget-development','nuget-integration','nuget-qa','nuget-stable')) {
        $script:content | Should -Match ('key="{0}"' -f [regex]::Escape($key))
      }
    }

    It 'Contains nuget.org' {
      $script:content | Should -Match 'key="nuget.org"'
    }

    It 'Uses /v3/index.json paths for ProGet feeds' {
      foreach ($key in @('nuget-experimental','nuget-development','nuget-integration','nuget-qa','nuget-stable')) {
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
      foreach ($key in @('nuget-experimental','nuget-development','nuget-integration','nuget-qa','nuget-stable')) {
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

  Context 'Custom ProGetBaseUrl' {
    It 'Substitutes a non-default ProGetBaseUrl into every ProGet feed URL' {
      New-SprintStage1 `
        -GitRoot $script:tempGitRoot `
        -Owner 'owner' `
        -SprintNumber '0007' `
        -ProGetBaseUrl 'http://proget.internal:51000' `
        -Confirm:$false | Out-Null

      $content = Get-Content -LiteralPath $script:nugetConfigPath -Raw
      foreach ($key in @('nuget-experimental','nuget-development','nuget-integration','nuget-qa','nuget-stable')) {
        $content | Should -Match ('http://proget\.internal:51000/nuget/{0}/v3/index\.json' -f [regex]::Escape($key))
      }
      $content | Should -Not -Match 'http://localhost:50000'
    }
  }
}

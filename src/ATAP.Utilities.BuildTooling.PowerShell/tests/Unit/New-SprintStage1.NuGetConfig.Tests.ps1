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

  function global:Assert-GitAvailable { }

  function global:gh {
    return 'https://github.com/owner/repo/issues/999'
  }
  $global:LASTEXITCODE = 0

  function global:git {
    $global:LASTEXITCODE = 0
    return ''
  }

  function global:Set-WorktreeJunctions {
    [PSCustomObject]@{
      Success           = $true
      JunctionsCreated  = 3
      Errors            = @()
    }
  }

  function global:Initialize-DownstreamSprintFromSharedVSCode { }

  . "$PSScriptRoot\..\..\public\New-SprintStage1.ps1"
}

Describe 'New-SprintStage1 NuGet.config generation (A09)' -Tag 'Unit', 'PendingStreamK' {

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

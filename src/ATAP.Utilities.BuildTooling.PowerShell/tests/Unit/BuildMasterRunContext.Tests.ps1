#Requires -Version 7.0

BeforeAll {
  $script:repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
  $script:plansDir = Join-Path $script:repoRoot 'src/ATAP.Utilities.BuildTooling.BuildMaster/Plans'
  . (Join-Path $script:plansDir 'BuildMasterRunContext.Common.ps1')

  if (-not (Get-Command Test-PromotionWithinCeiling -CommandType Function -ErrorAction SilentlyContinue)) {
    function global:Test-PromotionWithinCeiling {
      param(
        [string]$CurrentTier,
        [string]$CeilingTier,
        [switch]$AsBoolean
      )

      $order = @{
        Experimental = 0
        Development  = 1
        Integration  = 2
        QA           = 3
        Production   = 4
      }

      return ($order[$CurrentTier] -le $order[$CeilingTier])
    }
  }
}

Describe 'BuildMaster run context helper' -Tag 'Unit' {
  BeforeEach {
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('BuildMasterRunContext_' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
  }

  AfterEach {
    if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
      Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'derives the build-id scoped context directory' {
    $result = Resolve-BuildMasterRunContextPath -SourcePath $script:tempRoot -BuildMasterBuildId '4271'
    $expected = [System.IO.Path]::GetFullPath((Join-Path -Path $script:tempRoot -ChildPath '_generated/buildmaster/4271'))

    $result | Should -Be $expected
  }

  It 'rejects missing build ids' {
    { Resolve-BuildMasterRunContextPath -SourcePath $script:tempRoot -BuildMasterBuildId ' ' } |
      Should -Throw -ExpectedMessage '*BuildMasterBuildId is required*'
  }

  It 'isolates state files by build id' {
    $first = Initialize-BuildMasterRunContextDirectory -SourcePath $script:tempRoot -BuildMasterBuildId '1001'
    $second = Initialize-BuildMasterRunContextDirectory -SourcePath $script:tempRoot -BuildMasterBuildId '1002'

    $first | Should -Not -Be $second
    Write-BuildMasterRunContextTextFile -Path (Join-Path $first '_ceiling_tier.tmp') -Value 'Development'
    Write-BuildMasterRunContextTextFile -Path (Join-Path $second '_ceiling_tier.tmp') -Value 'QA'

    Get-Content -LiteralPath (Join-Path $first '_ceiling_tier.tmp') -Raw | Should -Be 'Development'
    Get-Content -LiteralPath (Join-Path $second '_ceiling_tier.tmp') -Raw | Should -Be 'QA'
  }

  It 'rejects conflicting captured versions for the same build id' {
    $contextDirectory = Initialize-BuildMasterRunContextDirectory -SourcePath $script:tempRoot -BuildMasterBuildId '4271'
    $allow = @{ Experimental = $true; Development = $true; Integration = $false; QA = $false; Production = $false }

    Write-BuildMasterRunContextJson `
      -ContextDirectory $contextDirectory `
      -BuildMasterBuildId '4271' `
      -ApplicationName 'ATAP.Utilities' `
      -SourcePath $script:tempRoot `
      -CurrentTier 'Experimental' `
      -CeilingTier 'Development' `
      -ResolvedVersion '1.2.3-Alpha.4' `
      -PrereleaseLabel 'Alpha.4' `
      -AllowDecisions $allow | Out-Null

    {
      Write-BuildMasterRunContextJson `
        -ContextDirectory $contextDirectory `
        -BuildMasterBuildId '4271' `
        -ApplicationName 'ATAP.Utilities' `
        -SourcePath $script:tempRoot `
        -CurrentTier 'Development' `
        -CeilingTier 'Development' `
        -ResolvedVersion '1.2.3-Beta.1' `
        -PrereleaseLabel 'Beta.1' `
        -AllowDecisions $allow
    } | Should -Throw -ExpectedMessage '*captured version*'
  }

  It 'preserves existing state-file evidence when later writes add bundle data' {
    $contextDirectory = Initialize-BuildMasterRunContextDirectory -SourcePath $script:tempRoot -BuildMasterBuildId '4271'
    $allow = @{ Experimental = $true; Development = $false; Integration = $false; QA = $false; Production = $false }

    Write-BuildMasterRunContextJson `
      -ContextDirectory $contextDirectory `
      -BuildMasterBuildId '4271' `
      -ApplicationName 'AceCommander' `
      -SourcePath $script:tempRoot `
      -CurrentTier 'Experimental' `
      -CeilingTier 'Experimental' `
      -ResolvedVersion '1.2.3-Sprint.4' `
      -PrereleaseLabel 'Sprint.4' `
      -AllowDecisions $allow `
      -StateFiles @{ CurrentTier = 'current.tmp' } | Out-Null

    Write-BuildMasterRunContextJson `
      -ContextDirectory $contextDirectory `
      -BuildMasterBuildId '4271' `
      -ApplicationName 'AceCommander' `
      -SourcePath $script:tempRoot `
      -CurrentTier 'Experimental' `
      -CeilingTier 'Experimental' `
      -ResolvedVersion '1.2.3-Sprint.4' `
      -PrereleaseLabel 'Sprint.4' `
      -AllowDecisions $allow `
      -AdditionalData @{ BundleVersion = '1.2.3-Sprint.4' } | Out-Null

    $json = Read-BuildMasterRunContextJson -ContextDirectory $contextDirectory
    $json.StateFiles.CurrentTier | Should -Be 'current.tmp'
    $json.BundleVersion | Should -Be '1.2.3-Sprint.4'
  }

  It 'rejects malformed context JSON' {
    $contextDirectory = Initialize-BuildMasterRunContextDirectory -SourcePath $script:tempRoot -BuildMasterBuildId '4271'
    Set-Content -LiteralPath (Join-Path $contextDirectory 'build-context.json') -Value '{not-json' -NoNewline

    { Read-BuildMasterRunContextJson -ContextDirectory $contextDirectory } |
      Should -Throw -ExpectedMessage '*malformed*'
  }

  It 'rejects writes when a required state file key is missing' {
    {
      Write-BuildMasterRunStateFiles -StateFiles @{ CurrentTier = (Join-Path $script:tempRoot 'current.tmp') } -Values @{
        CurrentTier = 'Experimental'
        CeilingTier = 'Development'
      }
    } | Should -Throw -ExpectedMessage "*does not define key 'CeilingTier'*"
  }

  It 'cleans old contexts while preserving the active build id' {
    $active = Initialize-BuildMasterRunContextDirectory -SourcePath $script:tempRoot -BuildMasterBuildId 'active'
    $old = Initialize-BuildMasterRunContextDirectory -SourcePath $script:tempRoot -BuildMasterBuildId 'old'
    (Get-Item -LiteralPath $active).LastWriteTimeUtc = [DateTime]::UtcNow.AddDays(-30)
    (Get-Item -LiteralPath $old).LastWriteTimeUtc = [DateTime]::UtcNow.AddDays(-30)

    Clear-OldBuildMasterRunContexts -SourcePath $script:tempRoot -ActiveBuildMasterBuildId 'active' -RetentionDays 14

    Test-Path -LiteralPath $active | Should -BeTrue
    Test-Path -LiteralPath $old | Should -BeFalse
  }
}

Describe 'BuildMaster Otter plan run-context wiring' -Tag 'Unit' {
  BeforeAll {
    $script:planPaths = @(
      Join-Path $script:plansDir 'CSharpPackage-5Stage.otter'
      Join-Path $script:plansDir 'PowerShellModule-5Stage.otter'
      Join-Path $script:plansDir 'ReleaseBundle-6Stage.otter'
    )
    $script:powerShellRunnerPath = Join-Path $script:plansDir 'Invoke-PowerShellModuleBuildMasterStage.ps1'
  }

  It 'derives every plan context directory from $BuildMasterId(build)' {
    foreach ($planPath in $script:planPaths) {
      $text = Get-Content -LiteralPath $planPath -Raw

      $text | Should -Match '\$BuildMasterBuildId = \$BuildMasterId\(build\)'
      if ((Split-Path -Leaf $planPath) -eq 'PowerShellModule-5Stage.otter') {
        $text | Should -Match '-BuildMasterBuildId "\$BuildMasterBuildId"'
        $runnerText = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw
        $runnerText | Should -Match 'Initialize-BuildMasterRunContextDirectory -SourcePath \$SourcePath -BuildMasterBuildId \$BuildMasterBuildId'
      }
      else {
        $text | Should -Match '_generated\\buildmaster\\\$BuildMasterBuildId'
      }
    }
  }

  It 'moves Get-BuildContext preambles out of OtterScript one-liners' {
    foreach ($planPath in $script:planPaths) {
      $text = Get-Content -LiteralPath $planPath -Raw

      $text | Should -Not -Match 'Get-BuildContext'
      if ((Split-Path -Leaf $planPath) -eq 'PowerShellModule-5Stage.otter') {
        $text | Should -Match '-File "\$InvokePowerShellModuleStageScript"'
      }
      else {
        $text | Should -Match '-File "\$InitializeBuildContextScript"'
      }
    }
  }

  It 'does not read or write hard-coded flat buildmaster temp files' {
    foreach ($planPath in $script:planPaths) {
      $text = Get-Content -LiteralPath $planPath -Raw

      $text | Should -Not -Match '_generated\\buildmaster\\_'
      $text | Should -Not -Match '_generated\\buildmaster\\releasebundle_'
      $text | Should -Not -Match '_generated\\buildmaster\\\$ModuleName'
    }
  }

  It 'uses the captured module resolved version instead of an injected package version' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Not -Match '\$PackageVersion'
    $text | Should -Match '\$capturedResolvedVersion'
  }

  It 'delegates PowerShell module build/test/pack semantics to Invoke-ModuleBuildWithRetry' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match 'Invoke-ModuleBuildWithRetry'
    $text | Should -Match '-Task CI'
    $text | Should -Match '-SkipPublish'
    $text | Should -Not -Match 'New-PSModuleNupkg'
  }

  It 'filters Invoke-ModuleBuildWithRetry success-stream noise before evaluating ExitCode' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match 'Select-ModuleBuildRetryResult'
    $text | Should -Match "PSObject\.Properties\.Name -contains 'ExitCode'"
    $text | Should -Match '\$moduleBuildRetryResults'
    $text | Should -Match '\[int\]\$_.ExitCode -ne 0'
  }

  It 'uses the ProGet PowerShellGet feed service root for publish' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match "\{0\}/nuget/\{1\}/"
    $text | Should -Not -Match "\{0\}/nuget/\{1\}/v3/index\.json"
    $text | Should -Match 'Add-BuildMasterPublishTrace'
  }

  It 'translates BuildMaster stage names to the current module.build.ps1 tier names' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match "'experimental' \{ return 'Sprint' \}"
    $text | Should -Match "'development'\s+\{ return 'Alpha' \}"
    $text | Should -Match "'integration'\s+\{ return 'Beta' \}"
    $text | Should -Match "'qa'\s+\{ return 'QA' \}"
    $text | Should -Match "'production'\s+\{ return 'Production' \}"
  }
}

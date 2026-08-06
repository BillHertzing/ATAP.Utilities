#Requires -Version 7.0

BeforeAll {
  $script:repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
  $script:plansDir = Join-Path $script:repoRoot 'src/ATAP.Utilities.BuildTooling.BuildMaster/Plans'
  $script:monitorsDir = Join-Path $script:repoRoot 'src/ATAP.Utilities.BuildTooling.BuildMaster/Monitors'
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

  It 'atomically replaces context JSON without leaving temporary files' {
    $contextDirectory = Initialize-BuildMasterRunContextDirectory -SourcePath $script:tempRoot -BuildMasterBuildId '4271'
    $path = Join-Path $contextDirectory 'build-context.json'

    Write-BuildMasterJsonFileAtomically -Path $path -Content '{"version":1}'
    Write-BuildMasterJsonFileAtomically -Path $path -Content '{"version":2}'

    (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).version | Should -Be 2
    @(Get-ChildItem -LiteralPath $contextDirectory -Filter 'build-context.json.*.tmp').Count | Should -Be 0
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

Describe 'BuildMaster repository monitor wiring' -Tag 'Unit' {
  BeforeAll {
    $script:powerShellMonitorPath = Join-Path $script:monitorsDir 'PowerShellModule-RepositoryMonitors.otter'
  }

  It 'passes PowerShell module identity into the shared PowerShellModule pipeline' {
    $text = Get-Content -LiteralPath $script:powerShellMonitorPath -Raw

    $text | Should -Match 'GitHub::Repository-Monitor PowerShellModule-BuildTooling-Main-Monitor'
    $text | Should -Match 'GitHub::Repository-Monitor PowerShellModule-BuildTooling-Sprint-Monitor'
    ([regex]::Matches($text, 'PathFilter:\s*src/ATAP\.Utilities\.BuildTooling\.PowerShell/\*\*')).Count | Should -Be 2
    ([regex]::Matches($text, 'BuildVariables:\s*%\(Branch:\s*\$Branch,\s*ModuleName:\s*ATAP\.Utilities\.BuildTooling\.PowerShell,\s*PackageName:\s*ATAP\.Utilities\.BuildTooling\.PowerShell\)')).Count | Should -Be 2
    $text | Should -Not -Match 'BuildVariables:\s*%\(Branch:\s*\$Branch\)'
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
    $script:powerShellContextInitializerPath = Join-Path $script:plansDir 'Initialize-PowerShellModuleBuildContext.ps1'
  }

  It 'derives every plan context directory from $BuildMasterId(build)' {
    foreach ($planPath in $script:planPaths) {
      $text = Get-Content -LiteralPath $planPath -Raw

      $text | Should -Match '\$BuildMasterBuildId = \$BuildMasterId\(build\)'
      switch (Split-Path -Leaf $planPath) {
        'PowerShellModule-5Stage.otter' {
          $text | Should -Match '-BuildMasterBuildId "\$BuildMasterBuildId"'
          $runnerText = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw
          $runnerText | Should -Match 'Initialize-BuildMasterRunContextDirectory -SourcePath \$SourcePath -BuildMasterBuildId \$BuildMasterBuildId'
        }
        'CSharpPackage-5Stage.otter' {
          # The C# plan delegates context-directory derivation to its stage
          # runner; it threads the build id through rather than composing the
          # _generated\buildmaster\<id> path inline in OtterScript.
          $text | Should -Match '-BuildMasterBuildId "\$BuildMasterBuildId"'
        }
        default {
          # ReleaseBundle composes the build-id-scoped context dir inline.
          $text | Should -Match '_generated\\buildmaster\\\$BuildMasterBuildId'
        }
      }
    }
  }

  It 'moves Get-BuildContext preambles out of OtterScript one-liners' {
    foreach ($planPath in $script:planPaths) {
      $text = Get-Content -LiteralPath $planPath -Raw

      # Get-BuildContext must not be INVOKED inline in OtterScript; the preamble
      # moved to -File runner scripts. A descriptive comment that merely names it
      # (e.g. "so Get-BuildContext can resolve ...") is not a violation.
      $nonCommentText = (($text -split "\r?\n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
      $nonCommentText | Should -Not -Match 'Get-BuildContext'
      switch (Split-Path -Leaf $planPath) {
        'PowerShellModule-5Stage.otter' {
          $text | Should -Match '-File "\$InvokePowerShellModuleStageScript"'
          $text | Should -Match '-Stage "\$PipelineStageName"'
        }
        'CSharpPackage-5Stage.otter' {
          # C# invokes its stage runner directly (the context preamble lives in
          # the runner), so it has no separate Initialize-BuildContext step.
          $text | Should -Match '-File "\$InvokeCSharpPackageStageScript"'
        }
        default {
          # ReleaseBundle runs a dedicated Initialize-BuildContext step first.
          $text | Should -Match '-File "\$InitializeBuildContextScript"'
        }
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
    $scriptParamBlock = $text.Substring(0, $text.IndexOf('$ErrorActionPreference'))

    $scriptParamBlock | Should -Not -Match '\[string\]\$PackageVersion'
    $text | Should -Not -Match '-PackageVersion\s+\$ResolvedPackageVersion'
    $text | Should -Match '\$capturedResolvedVersion'
  }

  It 'trusts captured PowerShell module package metadata after Experimental when Get-BuildContext drifts' {
    foreach ($scriptPath in @($script:powerShellRunnerPath, $script:powerShellContextInitializerPath)) {
      $text = Get-Content -LiteralPath $scriptPath -Raw

      $text | Should -Match 'continuing with captured immutable package version'
      $text | Should -Match '\$effectiveCeilingTier'
      $text | Should -Match 'Get-BuildMasterAllowDecisions -CeilingTier \$effectiveCeilingTier'
      $text | Should -Match '-CeilingTier \$effectiveCeilingTier'
      $text | Should -Not -Match 'but this stage resolved'
    }
  }

  It 'delegates PowerShell module build/test/pack semantics to Invoke-ModuleBuildWithRetry' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match 'Invoke-ModuleBuildWithRetry'
    $text | Should -Match '-Task CI'
    $text | Should -Match '-SkipPublish'
    $text | Should -Match '-OutputRoot \$moduleBuildOutputRoot'
    $text | Should -Not -Match 'New-PSModuleNupkg'
  }

  It 'uses a build-id scoped PowerShell module output root for BuildMaster package staging' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match '\$moduleBuildOutputRoot = Join-Path -Path \$contextDirectory'
    $text | Should -Match '\$moduleBuildPackageOutputPath = Join-Path -Path \$moduleBuildOutputRoot'
    $text | Should -Match 'build-scoped package output'
    $text | Should -Not -Match '_generated/psmodules/\$ModuleName/packages'
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

  It 'registers ProGet PowerShellGet repositories as NuGet v2 PSResourceGet repositories' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match 'Register-PSResourceRepository -Name \$Name -Uri \$Uri -Trusted -ApiVersion V2'
    $text | Should -Match 'Set-PSResourceRepository -Name \$Name -Uri \$Uri -Trusted -ApiVersion V2'
    $text | Should -Match 'ATAP\.BuildMaster\.PSResourceRepository'
    $text | Should -Match 'WaitOne\(\[TimeSpan\]::FromMinutes\(2\)\)'
  }

  It 'uses a build-scoped signature-verification evidence directory' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match '-EvidenceRoot \(Join-Path -Path \$contextDirectory -ChildPath ''promotion-signature-verification''\)'
  }

  It 'translates BuildMaster stage names to the current module.build.ps1 tier names' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match "'experimental' \{ return 'Sprint' \}"
    $text | Should -Match "'development'\s+\{ return 'Alpha' \}"
    $text | Should -Match "'integration'\s+\{ return 'Beta' \}"
    $text | Should -Match "'qa'\s+\{ return 'QA' \}"
    $text | Should -Match "'production'\s+\{ return 'Production' \}"
  }

  It 'auto-advances promoted PowerShell module stages through the version ceiling' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match 'PowerShell module runner will execute tier\(s\):'
    $text | Should -Match '\$tierIndex -le \$ceilingTierIndex'
    $text | Should -Match 'Invoke-PowerShellModulePromotionAndTests -Tier \$tierToRun'
    $text | Should -Match 'Get-PreviousBuildMasterTier -Tier \$Tier'
    $text | Should -Match '\$feedByTier\[\$previousTier\]'
    $text | Should -Match '\$feedByTier\[\$Tier\]'
    $text | Should -Match 'Promote-ProGetPackage'
    $text | Should -Match '-FromFeed \$sourceFeed'
    $text | Should -Match '-ToFeed \$destinationFeed'
    $text | Should -Match '-CeilingTier \$ceilingTier'
    $text | Should -Match 'Invoke-PromotedModuleTests'
    $text | Should -Match '-Feed \$destinationFeed'
    $text | Should -Match '\$\(\$Tier\)TestResults'
    $text | Should -Match '-ProGetBaseUrl \$ProGetUrl'
    $text | Should -Match '-ProGetApiKeySecretName \$ProGetApiKeySecretName'
    $text | Should -Not -Match '-ApiKey\s+\$script:resolvedProGetApiKey'
    $text | Should -Match 'next stage gate'
    $text | Should -Match "starting promotion/test"
    $text | Should -Not -Match 'promotion/test execution.*not implemented yet'
  }

  It 'records completed PowerShell module tiers to make auto-advance idempotent' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match 'Get-PowerShellModuleStageCompletionMarkerPath'
    $text | Should -Match 'Test-PowerShellModuleStageCompleted'
    $text | Should -Match 'Set-PowerShellModuleStageCompleted'
    $text | Should -Match 'already completed for build'
  }

  It 'fails PowerShell module deployments that are above the version ceiling' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match "exceeds version ceiling"
    $text | Should -Match 'Refusing deployment so BuildMaster does not advance stages above the package ceiling'
    $text | Should -Not -Match 'Skipping PowerShell module stage ''\$tier'' because ceiling'
  }

  It 'refuses successful no-op deployments once a non-final ceiling tier has already completed' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match 'already completed for build ''\$BuildMasterBuildId'' and ceiling ''\$ceilingTier'' has been reached'
    $text | Should -Match 'Refusing a successful no-op deployment because BuildMaster would advance the next stage above the ceiling'
    $text | Should -Match 'final stage ''\$tierToRun'' already completed for build ''\$BuildMasterBuildId''; accepting no-op deployment'
  }

  It 'uses the package version from the captured nupkg path for PowerShell promotion' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match 'Get-PowerShellModulePackageVersionFromNupkgPath'
    $text | Should -Match '\$packageVersionForRun = Get-PowerShellModulePackageVersionFromNupkgPath'
    $text | Should -Match '-Version \$PromotedPackageVersion'
    $text | Should -Match 'PackageVersion'
    $text | Should -Match 'Captured resolved version'
  }

  It 'lets Promote-ProGetPackage own promotion idempotency without a destination preflight' {
    $text = Get-Content -LiteralPath $script:powerShellRunnerPath -Raw

    $text | Should -Match 'Promoting ''\$PackageName'' version ''\$PromotedPackageVersion'' from ''\$sourceFeed'' to ''\$destinationFeed'''
    $text | Should -Match 'Promote-ProGetPackage `'
    $text | Should -Not -Match 'Test-ProGetPackageVersionInFeed -BaseUrl \$ProGetUrl -FeedName \$destinationFeed'
    $text | Should -Not -Match 'Checking whether .* already exists in .* before promotion'
  }
}

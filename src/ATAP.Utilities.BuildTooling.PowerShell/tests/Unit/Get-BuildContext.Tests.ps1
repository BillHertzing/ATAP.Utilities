#Requires -Version 7.0
# Pester 5+ tests for Get-BuildContext (Stream H, task H1).
# All external calls (git, nbgv) and filesystem probes are mocked.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Resolve-FeatureSlug.ps1')
  . (Join-Path $publicDir 'Get-BuildContext.ps1')

  # Suppress PSFramework noise in tests.
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  # Provide stand-in 'git' and 'nbgv' functions so Mock can replace them.
  # IMPORTANT: paramless stubs — when the stub declares a parameter (even one
  # named 'args' via ValueFromRemainingArguments), Pester's Mock invocation
  # passes the call args as a named-parameter wrapper, corrupting `$args`
  # inside the MockWith body. With a paramless stub, `$args` inside the
  # MockWith body holds the original call arguments verbatim, which is what
  # the switch-Regex match below relies on.
  if (-not (Get-Command 'git' -CommandType Function -ErrorAction SilentlyContinue)) {
    function global:git { }
  }
  if (-not (Get-Command 'nbgv' -CommandType Function -ErrorAction SilentlyContinue)) {
    function global:nbgv { }
  }

  $script:fakeRepoRoot = (Join-Path ([System.IO.Path]::GetTempPath()) ('GetBuildContextTest_' + [Guid]::NewGuid().ToString('N')))
  New-Item -ItemType Directory -Path $script:fakeRepoRoot -Force | Out-Null

  # Get-BuildContext now requires a -ProjectPath that contains a project-adjacent
  # version.json. Stand up a fake project under the fake repo root so the BEGIN-
  # block validation succeeds without mocking Resolve-Path / Test-Path.
  $script:fakeProjectPath = Join-Path $script:fakeRepoRoot 'src/FakeProject'
  New-Item -ItemType Directory -Path $script:fakeProjectPath -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $script:fakeProjectPath 'version.json') `
    -Value '{"version":"0.1-Sprint.{height}"}' -NoNewline
}

AfterAll {
  if ($script:fakeRepoRoot -and (Test-Path -LiteralPath $script:fakeRepoRoot)) {
    Remove-Item -LiteralPath $script:fakeRepoRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe 'Get-BuildContext' -Tag 'Unit' {

  BeforeEach {
    # Default mocks: succeed with a sprint-trunk-style version.
    Mock git {
      $global:LASTEXITCODE = 0
      switch -Regex ($args -join ' ') {
        'rev-parse --show-toplevel' { return $script:fakeRepoRoot }
        'symbolic-ref --short HEAD' { return 'main' }
        'rev-parse HEAD'            { return 'abcdef0123456789abcdef0123456789abcdef01' }
        default                     { return '' }
      }
    }
    Mock nbgv {
      $global:LASTEXITCODE = 0
      return '0.1.0-Sprint.42'
    }
    Mock Get-Command -ParameterFilter { $Name -eq 'nbgv' } -MockWith { [PSCustomObject]@{ Name = 'nbgv' } }
    # Test-Path is intentionally NOT defaulted here. The default (real) Test-Path
    # returns $false against the fake repo root because no db YAML exists, which
    # matches the absent-asset test. The present-asset test layers its own Mock
    # inside the It block.
  }

  Context 'Parameter set enforcement (-ReleaseTag vs -Branch mutex)' {
    It 'Throws when neither -ReleaseTag nor -Branch is supplied' {
      { Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath } |
        Should -Throw -ExpectedMessage '*Either -Branch or -ReleaseTag is required*'
    }

    It 'Throws when both -ReleaseTag and -Branch are supplied' {
      { Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -ReleaseTag 'v1.0.0' -Branch 'main' } | Should -Throw
    }

    It 'Accepts -Branch alone' {
      { Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main' } | Should -Not -Throw
    }

    It 'Accepts -ReleaseTag alone (resolves Branch from HEAD)' {
      { Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -ReleaseTag 'v1.0.0' } | Should -Not -Throw
    }
  }

  Context '-ProjectPath validation' {
    It 'Throws when -ProjectPath does not exist' {
      $missing = Join-Path $script:fakeRepoRoot 'src/DoesNotExist'
      { Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $missing -Branch 'main' } |
        Should -Throw -ExpectedMessage "*could not be resolved*"
    }

    It 'Throws when -ProjectPath lacks a project-adjacent version.json' {
      $noVersion = Join-Path $script:fakeRepoRoot 'src/NoVersionJson'
      New-Item -ItemType Directory -Path $noVersion -Force | Out-Null
      try {
        { Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $noVersion -Branch 'main' } |
          Should -Throw -ExpectedMessage "*does not contain a project-adjacent 'version.json'*"
      } finally {
        Remove-Item -LiteralPath $noVersion -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'BranchType derivation' {
    $branchCases = @(
      @{ Branch = 'main';                       Expected = 'stable' }
      @{ Branch = 'feature/payment-refactor';   Expected = 'feature' }
      @{ Branch = 'sprint/0007-work-items';     Expected = 'sprint' }
      @{ Branch = 'release/1.0.0';              Expected = 'release' }
      @{ Branch = 'hotfix/something';           Expected = 'stable' }
      @{ Branch = 'develop';                    Expected = 'stable' }
    )

    It "Maps branch '<Branch>' to BranchType '<Expected>'" -TestCases $branchCases {
      param($Branch, $Expected)
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch $Branch
      $ctx.BranchType | Should -Be $Expected
    }
  }

  Context 'Tier derivation from prerelease label' {
    $tierCases = @(
      @{ Version = '1.0.0';                         ExpectedTier = 'Production';  ExpectedLabel = '' }
      @{ Version = '0.1.0-Alpha.5';                 ExpectedTier = 'Development'; ExpectedLabel = 'Alpha' }
      @{ Version = '0.1.0-Beta.3';                  ExpectedTier = 'Integration'; ExpectedLabel = 'Beta' }
      @{ Version = '0.1.0-QA.1';                    ExpectedTier = 'QA';          ExpectedLabel = 'QA' }
      @{ Version = '0.1.0-Sprint.42';               ExpectedTier = 'Experimental'; ExpectedLabel = 'Sprint' }
      @{ Version = '0.1.0-PaymentRefactor.7';       ExpectedTier = 'Experimental'; ExpectedLabel = 'PaymentRefactor' }
    )

    It "Maps version '<Version>' to Tier '<ExpectedTier>' (label '<ExpectedLabel>')" -TestCases $tierCases {
      param($Version, $ExpectedTier, $ExpectedLabel)
      Mock nbgv { $global:LASTEXITCODE = 0; return $Version }
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main'
      $ctx.Tier | Should -Be $ExpectedTier
      $ctx.PrereleaseLabel | Should -Be $ExpectedLabel
    }
  }

  Context 'FeatureSlug derivation' {
    It 'Sets FeatureSlug for feature branches' {
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'feature/payment-refactor'
      $ctx.FeatureSlug | Should -Be 'PaymentRefactor'
    }

    It 'Sets FeatureSlug to $null for non-feature branches' {
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main'
      $ctx.FeatureSlug | Should -BeNullOrEmpty
    }
  }

  Context 'DbAssetsIncluded toggle' {
    It 'Reports DbAssetsIncluded=$false when the YAML is absent' {
      # No Mock — the real Test-Path returns $false because the path under the
      # fake repo root does not exist.
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main'
      $ctx.DbAssetsIncluded | Should -BeFalse
    }

    It 'Reports DbAssetsIncluded=$true when the YAML exists' {
      # Join-Path on Windows converts the child-path slashes to backslashes, so
      # match either separator with a regex rather than a forward-slash glob.
      Mock Test-Path -ParameterFilter { $LiteralPath -and $LiteralPath -match '[\\/]db[\\/].+[\\/]releases[\\/].+\.yml$' } -MockWith { $true }
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main'
      $ctx.DbAssetsIncluded | Should -BeTrue
    }
  }

  Context 'MajorMinorPatch parsing' {
    It 'Extracts the X.Y.Z core from a labelled version' {
      Mock nbgv { $global:LASTEXITCODE = 0; return '2.3.4-Alpha.9' }
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main'
      $ctx.MajorMinorPatch | Should -Be '2.3.4'
    }

    It 'Extracts the X.Y.Z core from a bare production version' {
      Mock nbgv { $global:LASTEXITCODE = 0; return '5.0.0' }
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main'
      $ctx.MajorMinorPatch | Should -Be '5.0.0'
    }
  }

  Context '-ReleaseTag mode resolves branch from HEAD' {
    It 'Calls git symbolic-ref --short HEAD when -ReleaseTag is supplied' {
      Mock git {
        $global:LASTEXITCODE = 0
        switch -Regex ($args -join ' ') {
          'rev-parse --show-toplevel' { return $script:fakeRepoRoot }
          'symbolic-ref --short HEAD' { return 'release/1.4.0' }
          'rev-parse HEAD'            { return 'fedcba9876543210fedcba9876543210fedcba98' }
        }
      }
      $ctx = Get-BuildContext -Application 'AceCommander' -ProjectPath $script:fakeProjectPath -ReleaseTag 'v1.4.0'
      $ctx.Branch | Should -Be 'release/1.4.0'
      $ctx.BranchType | Should -Be 'release'
      $ctx.SourceTag | Should -Be 'v1.4.0'
    }
  }

  Context 'nbgv missing-on-PATH guard' {
    It 'Throws with the documented install hint when nbgv is not available' {
      Mock Get-Command -ParameterFilter { $Name -eq 'nbgv' } -MockWith { $null }
      { Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main' } |
        Should -Throw -ExpectedMessage '*dotnet tool install -g nbgv*'
    }
  }

  Context 'Required-field surface' {
    It 'Returns an object with every documented field' {
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main'
      foreach ($field in @(
          'Application', 'ProjectPath', 'Branch', 'BranchType', 'FeatureSlug',
          'RepoRoot', 'SourceTag', 'SourceCommit', 'ResolvedPackageVersion',
          'MajorMinorPatch', 'PrereleaseLabel', 'CurrentTier', 'CeilingTier',
          'Tier', 'IsAtCeiling', 'DbAssetsIncluded'
        )) {
        $ctx.PSObject.Properties.Name | Should -Contain $field
      }
    }

    It 'Pass-through Application is preserved' {
      $ctx = Get-BuildContext -Application 'MyApp.Custom' -ProjectPath $script:fakeProjectPath -Branch 'main'
      $ctx.Application | Should -Be 'MyApp.Custom'
    }
  }
}

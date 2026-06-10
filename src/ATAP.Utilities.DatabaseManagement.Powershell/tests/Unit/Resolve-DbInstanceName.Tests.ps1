#Requires -Version 7.0
# Pester 5+ tests for Resolve-DbInstanceName (Stream J, task J1).
# Pure function; no external dependencies need to be mocked.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Resolve-DbInstanceName.ps1')

  # Suppress PSFramework noise in tests.
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
}

Describe 'Resolve-DbInstanceName' -Tag 'Unit' {

  Context 'Canonical examples from Database-Change-Unit-and-Flyway-Promotion.md §5' {
    # One row per documented Kind. Application='AceCommander' matches the
    # examples in §5.1.
    $cases = @(
      @{ Kind = 'developer-scratch';   GitHandle = 'wh'; FeatureSlug = '';                 Expected = 'AceCommander-dev-wh' }
      @{ Kind = 'feature-sprint';      GitHandle = 'wh'; FeatureSlug = 'PaymentRefactor';  Expected = 'AceCommander-PaymentRefactor-wh' }
      @{ Kind = 'feature-shared';      GitHandle = '';   FeatureSlug = 'PaymentRefactor';  Expected = 'AceCommander-PaymentRefactor-shared' }
      @{ Kind = 'trunk-dev';           GitHandle = '';   FeatureSlug = '';                 Expected = 'AceCommander-dev' }
      @{ Kind = 'trunk-integration';   GitHandle = '';   FeatureSlug = '';                 Expected = 'AceCommander-integration' }
      @{ Kind = 'trunk-qa';            GitHandle = '';   FeatureSlug = '';                 Expected = 'AceCommander-qa' }
      @{ Kind = 'customer-production'; GitHandle = '';   FeatureSlug = '';                 Expected = 'AceCommander' }
    )

    It "Kind '<Kind>' yields DB name '<Expected>'" -TestCases $cases {
      param($Kind, $GitHandle, $FeatureSlug, $Expected)
      $params = @{ Application = 'AceCommander'; Kind = $Kind }
      if (-not [string]::IsNullOrEmpty($GitHandle))   { $params['GitHandle']   = $GitHandle }
      if (-not [string]::IsNullOrEmpty($FeatureSlug)) { $params['FeatureSlug'] = $FeatureSlug }
      $result = Resolve-DbInstanceName @params
      $result | Should -Be $Expected
    }
  }

  Context 'GitHandle normalization (§5.1)' {
    It 'Truncates GitHandle to 12 characters' {
      # 'longerhandlename' is 16 chars; truncates to 'longerhandle' (12 chars).
      $result = Resolve-DbInstanceName -Application 'AceCommander' -Kind developer-scratch -GitHandle 'longerhandlename'
      $result | Should -Be 'AceCommander-dev-longerhandle'
    }

    It 'Lower-cases GitHandle (case-insensitive comparison per §5.1)' {
      $result = Resolve-DbInstanceName -Application 'AceCommander' -Kind developer-scratch -GitHandle 'BillH'
      $result | Should -Be 'AceCommander-dev-billh'
    }

    It 'Combines truncation and lowercasing' {
      $result = Resolve-DbInstanceName -Application 'AceCommander' -Kind developer-scratch -GitHandle 'BillHertzingTooLong'
      $result | Should -Be 'AceCommander-dev-billhertzing'
      # billhertzingtoolong -> billhertzingtoolong (truncate to 12) -> 'billhertzing'
      $result.Length | Should -BeLessOrEqual 64
    }
  }

  Context 'Required-parameter validation per Kind' {
    It 'Throws when developer-scratch is missing -GitHandle' {
      { Resolve-DbInstanceName -Application 'AceCommander' -Kind developer-scratch } |
        Should -Throw -ExpectedMessage "*requires -GitHandle*"
    }

    It 'Throws when feature-sprint is missing -GitHandle' {
      { Resolve-DbInstanceName -Application 'AceCommander' -Kind feature-sprint -FeatureSlug 'X' } |
        Should -Throw -ExpectedMessage "*requires -GitHandle*"
    }

    It 'Throws when feature-sprint is missing -FeatureSlug' {
      { Resolve-DbInstanceName -Application 'AceCommander' -Kind feature-sprint -GitHandle 'wh' } |
        Should -Throw -ExpectedMessage "*requires -FeatureSlug*"
    }

    It 'Throws when feature-shared is missing -FeatureSlug' {
      { Resolve-DbInstanceName -Application 'AceCommander' -Kind feature-shared } |
        Should -Throw -ExpectedMessage "*requires -FeatureSlug*"
    }

    It 'Rejects an unknown Kind at parameter binding (ValidateSet)' {
      { Resolve-DbInstanceName -Application 'AceCommander' -Kind 'not-a-real-kind' -GitHandle 'wh' } |
        Should -Throw
    }
  }

  Context 'Hyphens-only delimiter rule (§5.1)' {
    It 'Rejects an Application containing a dot' {
      { Resolve-DbInstanceName -Application 'ATAP.Utilities' -Kind trunk-dev } |
        Should -Throw -ExpectedMessage "*hyphens only*"
    }

    It 'Rejects an Application containing an underscore' {
      { Resolve-DbInstanceName -Application 'Ace_Commander' -Kind trunk-dev } |
        Should -Throw -ExpectedMessage "*hyphens only*"
    }

    It 'Rejects a GitHandle containing a dot' {
      { Resolve-DbInstanceName -Application 'AceCommander' -Kind developer-scratch -GitHandle 'a.b' } |
        Should -Throw -ExpectedMessage "*hyphens only*"
    }

    It 'Rejects a FeatureSlug containing an underscore' {
      { Resolve-DbInstanceName -Application 'AceCommander' -Kind feature-shared -FeatureSlug 'My_Slug' } |
        Should -Throw -ExpectedMessage "*hyphens only*"
    }
  }

  Context 'FeatureSlug length cap (§5.1: ≤16 chars)' {
    It 'Throws when -FeatureSlug exceeds 16 characters' {
      $longSlug = 'A' * 17
      { Resolve-DbInstanceName -Application 'AceCommander' -Kind feature-shared -FeatureSlug $longSlug } |
        Should -Throw -ExpectedMessage "*caps slugs at 16*"
    }

    It 'Accepts a FeatureSlug of exactly 16 characters' {
      $slug16 = 'A' * 16
      $result = Resolve-DbInstanceName -Application 'AceCommander' -Kind feature-shared -FeatureSlug $slug16
      $result | Should -Be "AceCommander-${slug16}-shared"
    }
  }

  Context 'Total length cap (§5.1: ≤64 chars)' {
    It 'Throws when the resulting DB name exceeds 64 characters' {
      # 50-char application name + '-PaymentRefactor-billh' (~22 chars) > 64.
      $longApp = ('X' * 50)
      { Resolve-DbInstanceName -Application $longApp -Kind feature-sprint -FeatureSlug 'PaymentRefactor' -GitHandle 'billh' } |
        Should -Throw -ExpectedMessage "*caps total length at 64*"
    }

    It 'Accepts a DB name of exactly 64 characters' {
      # 'A' x 46 + '-PaymentRefactor-x' = 46 + 1 + 15 + 1 + 1 = 64
      $app = 'A' * 46
      $result = Resolve-DbInstanceName -Application $app -Kind feature-sprint -FeatureSlug 'PaymentRefactor' -GitHandle 'x'
      $result.Length | Should -Be 64
      $result | Should -Be "$app-PaymentRefactor-x"
    }
  }

  Context 'Output type' {
    It 'Returns a [string]' {
      $result = Resolve-DbInstanceName -Application 'AceCommander' -Kind trunk-dev
      $result | Should -BeOfType ([string])
    }

    It 'Declares [string] as its OutputType' {
      $cmd = Get-Command Resolve-DbInstanceName
      ($cmd.OutputType | Select-Object -First 1).Type | Should -Be ([string])
    }
  }
}

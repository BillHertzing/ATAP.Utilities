#Requires -Version 7.0
# Pester 5+ tests for Resolve-FeatureSlug (Stream H, task H2).
# Pure function; no external dependencies need to be mocked.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Resolve-FeatureSlug.ps1')

  # Suppress PSFramework noise in tests.
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
}

Describe 'Resolve-FeatureSlug' -Tag 'Unit' {

  Context 'Canonical examples from Long-Developing-Features.md §2.1' {
    # Note: the documented example for 'feature/long-running-auth-overhaul'
    # shows 'LongRunningAuth' (15 chars) in the doc table. Per the literal
    # E-DEC-01 rule documented in §2 ("Truncate to 16 characters") the
    # actual derivation produces 'LongRunningAuthO' (16 chars), which is
    # what the cmdlet returns. The plan body for H2 (V3 §5) implements
    # the same 16-char Substring truncation. The doc's 15-char example
    # appears to use an unstated word-boundary truncation that conflicts
    # with the explicit rule; the rule wins.
    $cases = @(
      @{ BranchName = 'feature/payment-refactor';           Expected = 'PaymentRefactor' }
      @{ BranchName = 'feature/long-running-auth-overhaul'; Expected = 'LongRunningAuthO' }
      @{ BranchName = 'feature/db-schema-v2';               Expected = 'DbSchemaV2' }
    )

    It "Derives slug '<Expected>' from branch '<BranchName>'" -TestCases $cases {
      param($BranchName, $Expected)
      $result = Resolve-FeatureSlug -BranchName $BranchName
      $result | Should -Be $Expected
    }
  }

  Context 'Non-feature branches' {
    $nonFeatureCases = @(
      @{ BranchName = 'main' }
      @{ BranchName = 'sprint/0007-work-items' }
      @{ BranchName = 'release/1.0.0' }
      @{ BranchName = 'hotfix/fix-something' }
      @{ BranchName = 'someother/feature/branch' }
    )

    It "Returns `$null for non-feature branch '<BranchName>'" -TestCases $nonFeatureCases {
      param($BranchName)
      $result = Resolve-FeatureSlug -BranchName $BranchName
      $result | Should -BeNullOrEmpty
    }

    It 'Returns $null for empty / whitespace input' {
      Resolve-FeatureSlug -BranchName '' | Should -BeNullOrEmpty
      Resolve-FeatureSlug -BranchName '   ' | Should -BeNullOrEmpty
    }
  }

  Context 'Truncation to 16 characters' {
    It 'Truncates a long single-word feature slug to exactly 16 chars' {
      $result = Resolve-FeatureSlug -BranchName 'feature/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      $result.Length | Should -Be 16
      $result | Should -Be 'Aaaaaaaaaaaaaaaa'
    }

    It 'Truncates the long-running-auth example to exactly 16 chars (per E-DEC-01 rule)' {
      $result = Resolve-FeatureSlug -BranchName 'feature/long-running-auth-overhaul'
      $result.Length | Should -Be 16
      $result | Should -Be 'LongRunningAuthO'
    }

    It 'Does not truncate slugs that are already 16 chars or shorter' {
      $result = Resolve-FeatureSlug -BranchName 'feature/payment-refactor'
      $result.Length | Should -BeLessOrEqual 16
    }
  }

  Context '-DeveloperOffset parameter (forward-compatibility)' {
    It 'Accepts -DeveloperOffset without throwing' {
      { Resolve-FeatureSlug -BranchName 'feature/payment-refactor' -DeveloperOffset 5 } |
        Should -Not -Throw
    }

    It 'Does not change the slug when -DeveloperOffset is supplied (today)' {
      $baseline = Resolve-FeatureSlug -BranchName 'feature/payment-refactor'
      $withOffset = Resolve-FeatureSlug -BranchName 'feature/payment-refactor' -DeveloperOffset 7
      $withOffset | Should -Be $baseline
    }

    It 'Defaults DeveloperOffset to 0 when omitted' {
      $a = Resolve-FeatureSlug -BranchName 'feature/payment-refactor'
      $b = Resolve-FeatureSlug -BranchName 'feature/payment-refactor' -DeveloperOffset 0
      $a | Should -Be $b
    }
  }

  Context 'Edge cases in word splitting' {
    It 'Splits on hyphens, underscores, and forward slashes' {
      Resolve-FeatureSlug -BranchName 'feature/a-b_c/d' | Should -Be 'ABCD'
    }

    It 'Collapses consecutive separators' {
      Resolve-FeatureSlug -BranchName 'feature/a---b' | Should -Be 'AB'
    }

    It 'Single-character components are upper-cased correctly' {
      Resolve-FeatureSlug -BranchName 'feature/v-2' | Should -Be 'V2'
    }

    It 'All-numeric feature suffix still produces a string' {
      $result = Resolve-FeatureSlug -BranchName 'feature/123'
      $result | Should -Be '123'
    }
  }

  Context 'OutputType declaration' {
    It 'Declares [string] as its OutputType' {
      $cmd = Get-Command Resolve-FeatureSlug
      $outputTypeAttr = $cmd.OutputType | Select-Object -First 1
      $outputTypeAttr.Type | Should -Be ([string])
    }
  }
}
